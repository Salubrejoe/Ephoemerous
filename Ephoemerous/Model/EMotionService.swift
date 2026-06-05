import CoreMotion
import Observation

// MARK: - EMotionService
// Fused device attitude for the celestial canvas. Where
// `ELocationService` answers "where on Earth am I + which way is my
// compass," this answers "which way is the phone physically pointed,"
// expressed in the same horizon terms the projection speaks: azimuth
// (clockwise from true north) + altitude (above the horizon).
//
// Core Motion's `deviceMotion` already fuses gyro + accelerometer +
// magnetometer into one world-referenced attitude, so we don't
// hand-combine heading and pitch — we take the phone's aim axis,
// express it in the reference frame, and read the two angles straight
// off. No `NSMotionUsageDescription` is required: that key gates the
// pedometer / activity / altimeter APIs, not fused attitude. Device
// motion is unavailable in the Simulator, so `aim` stays nil there and
// `UserLocationLayer` falls back to the static heading cone.
@Observable
final class EMotionService {

    static let shared = EMotionService()

    /// The direction the phone is aimed, in observer-horizon terms.
    /// `azimuth` is clockwise from true north (N = 0, E = π/2);
    /// `altitude` is above the horizon (0 = level, π/2 = straight up,
    /// negative = aimed below the horizon). Both in radians. `nil`
    /// until Core Motion delivers its first sample, or whenever device
    /// motion is unavailable / stopped.
    struct Aim: Equatable {
        var azimuth:  Double
        var altitude: Double
    }

    private(set) var aim: Aim? = nil

    /// True while the phone is held UP toward the sky (screen tilted to
    /// face downward at the user). Hysteretic so it doesn't flutter at the
    /// boundary. Drives "engage compass mode on raise" — observed in
    /// `MainView`. `false` until the first sample / when motion is off.
    private(set) var raisedToSky: Bool = false

    // MARK: - Aim tuning  ▼ TWEAK HERE ▼  (device only — no gyro in the sim)

    /// Aim-axis blend band, measured on "screen-down-ness" (−m33, how far
    /// the screen-out normal leans below horizontal). Below `lo` the aim is
    /// the phone's TOP edge (reading / pointing pose); above `hi` it's the
    /// BACK-camera normal (held up to the sky); smoothstepped between, so
    /// the cone glides from one axis to the other as the phone lays back.
    private static let aimBlendLo = 0.25
    private static let aimBlendHi = 0.75

    /// Raise-to-sky thresholds (also on screen-down-ness) for the
    /// auto-compass trigger. Separate on/off values = hysteresis: it flips
    /// ON past `raiseOn` and only back OFF below `raiseOff`.
    private static let raiseOn  = 0.60
    private static let raiseOff = 0.40

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private let queue   = OperationQueue()

    private init() {
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        queue.name                         = "com.ephoemerous.motion"
        queue.maxConcurrentOperationCount  = 1
    }

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    /// Begin streaming attitude. Idempotent — safe on every foreground
    /// transition.
    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        guard !manager.isDeviceMotionActive   else { return }

        // True-north-referenced frame (X = true north, Z = up). Falls
        // back to the magnetic frame until a location fix calibrates
        // true north.
        let frames = CMMotionManager.availableAttitudeReferenceFrames()
        let frame: CMAttitudeReferenceFrame =
            frames.contains(.xTrueNorthZVertical)
            ? .xTrueNorthZVertical
            : .xMagneticNorthZVertical

        manager.startDeviceMotionUpdates(using: frame, to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let sample = Self.sample(from: motion.attitude)
            // @Observable writes must land on main. We also suppress
            // no-op writes so a still phone leaves the idle Canvas
            // parked (see `ECanvasSchedule`) instead of forcing a
            // 30 Hz redraw of the whole starfield.
            DispatchQueue.main.async {
                if sample.aim != self.aim { self.aim = sample.aim }

                // Raise-to-sky with hysteresis: flip ON above `raiseOn`,
                // back OFF below `raiseOff`. Only written on a real change.
                let raised = self.raisedToSky
                    ? sample.screenDown > Self.raiseOff
                    : sample.screenDown > Self.raiseOn
                if raised != self.raisedToSky { self.raisedToSky = raised }
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        aim = nil
        raisedToSky = false
    }

    // MARK: - Attitude → aim

    /// Convert a Core Motion attitude into the horizon-frame aim (azimuth +
    /// altitude) the projection speaks, blending TWO device axes by posture:
    ///
    ///   • TOP edge (device +Y) — the natural "reading / pointing" axis:
    ///     held upright or tilted back, its top points along your facing
    ///     azimuth and rises as you lift the phone.
    ///   • BACK normal (−device +Z) — the camera axis: when the phone is
    ///     held flat UP to the sky, this is what's actually pointed at the
    ///     stars overhead, while the top edge has fallen to the horizon.
    ///
    /// We blend top → back by "screen-down-ness" (−m33: how far the screen
    /// normal leans below horizontal), so a reading tilt follows the top
    /// edge and raising the phone overhead smoothly hands off to the back
    /// normal. Blending the 3-D vectors (then reading angles off the
    /// result) avoids azimuth wrap-around at the crossover.
    ///
    /// CONVENTION (resolved on hardware 2026-05-31): Apple's
    /// `attitude.rotationMatrix` maps REFERENCE → device (v_dev = M·v_ref),
    /// so a device axis in reference coords is the matching ROW of M.
    /// Device +Y (top) → row 2 = (m21, m22, m23); device +Z (screen-out) →
    /// row 3 = (m31, m32, m33). Reference frame: X = true north, Y = west,
    /// Z = up. Returns the aim plus the raw screen-down-ness (for the
    /// raise-to-sky trigger).
    private static func sample(from attitude: CMAttitude) -> (aim: Aim, screenDown: Double) {
        let m = attitude.rotationMatrix

        // Top edge (device +Y) and back-camera normal (−device +Z), each in
        // reference-frame (north, west, up) components.
        let tN = m.m21, tW = m.m22, tU = m.m23
        let bN = -m.m31, bW = -m.m32, bU = -m.m33

        // Screen-out normal's downward lean: ~0 upright, →1 held flat
        // overhead (screen facing the user, back to the sky).
        let screenDown = max(0, -m.m33)
        let w = smoothstep(screenDown, lo: aimBlendLo, hi: aimBlendHi)

        // Blend, then normalise.
        var n = (1 - w) * tN + w * bN
        var west = (1 - w) * tW + w * bW
        var up = (1 - w) * tU + w * bU
        let len = (n * n + west * west + up * up).squareRoot()
        if len > 1e-9 { n /= len; west /= len; up /= len }

        let altitude = asin(max(-1, min(1, up)))
        let azimuth  = atan2(-west, n)            // clockwise from north

        let aim = Aim(azimuth: quantize(azimuth), altitude: quantize(altitude))
        return (aim, screenDown)
    }

    /// Smoothstep 0→1 across [lo, hi].
    private static func smoothstep(_ x: Double, lo: Double, hi: Double) -> Double {
        guard hi > lo else { return x < lo ? 0 : 1 }
        let t = min(1, max(0, (x - lo) / (hi - lo)))
        return t * t * (3 - 2 * t)
    }

    /// Round to ~0.5° so magnetometer micro-jitter on a still phone
    /// doesn't publish a fresh value (and wake the idle Canvas) every
    /// single sample. A 0.5° step is invisible under the soft blob.
    private static func quantize(_ radians: Double) -> Double {
        let step = 0.5 * .pi / 180
        return (radians / step).rounded() * step
    }
}

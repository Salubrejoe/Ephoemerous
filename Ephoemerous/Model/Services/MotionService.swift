import CoreMotion
import simd
import Observation

// MARK: - MotionService
// Fused device attitude for the celestial canvas. Where
// `LocationService` answers "where on Earth am I + which way is my
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
final class MotionService {

    static let shared = MotionService()

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

    /// True while the phone is held UP toward the sky, belly down (screen
    /// tilted to face downward at the user). Hysteretic so it doesn't
    /// flutter at the boundary. Arms LOOK mode — observed in `MainView`
    /// (see `AppState+Look`). `false` until the first sample / when motion
    /// is off.
    private(set) var raisedToSky: Bool = false

    /// The phone's full pose, for LOOK mode — the window you hold up to
    /// the sky. Two unit vectors in the local horizon frame (north, west,
    /// up): `back`, where the back camera points (the window's line of
    /// sight), and `up`, where the top edge points (the window's up).
    /// Low-passed against hand tremor and only republished on a real move,
    /// so a still hand leaves the sky parked. `nil` until the first sample.
    struct Pose: Equatable {
        var back: SIMD3<Double>
        var up:   SIMD3<Double>
    }

    private(set) var pose: Pose? = nil

    // MARK: - Aim tuning  ▼ TWEAK HERE ▼  (device only — no gyro in the sim)

    /// Aim-axis blend band, measured on "screen-down-ness" (−m33, how far
    /// the screen-out normal leans below horizontal). Below `lo` the aim is
    /// the phone's TOP edge (reading / pointing pose); above `hi` it's the
    /// BACK-camera normal (held up to the sky); smoothstepped between, so
    /// the cone glides from one axis to the other as the phone lays back.
    ///
    /// Band centred on `screenDown = 0.5` — the face-down/face-up boundary —
    /// and kept TIGHT so the axis actually toggles around that crossover
    /// (only once the phone is more face-down than face-up) rather than
    /// drifting the whole tilt range. Widen [lo, hi] for a softer glide,
    /// narrow it toward 0.5 for a crisper switch. ▼ TWEAK band width here ▼
    private static let aimBlendLo = 0.40
    private static let aimBlendHi = 0.60

    /// Raise-to-sky thresholds (also on screen-down-ness) for the
    /// auto-compass trigger. Separate on/off values = hysteresis: it flips
    /// ON past `raiseOn` and only back OFF below `raiseOff`.
    private static let raiseOn  = 0.60
    private static let raiseOff = 0.40

    /// Pose smoothing, 0…1 per sample: lower = steadier but laggier.
    /// ▼ TWEAK the window's steadiness here ▼
    private static let poseSmoothing = 0.35
    /// Smallest move (degrees) that republishes the pose.
    private static let poseStepDeg   = 0.08

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private let queue   = OperationQueue()

    private init() {
        // 60 Hz: LOOK mode moves the whole sky with the hand, and 30 read
        // as judder. A still hand still publishes nothing (see `pose`).
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
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
            // parked (see `CanvasSchedule`) instead of forcing a
            // 30 Hz redraw of the whole starfield.
            DispatchQueue.main.async {
                if sample.aim != self.aim { self.aim = sample.aim }
                if let pose = sample.pose, Self.moved(from: self.pose, to: pose) { self.pose = pose }

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
        pose = nil
        queue.addOperation { Self.smoothedPose = nil }     // the motion queue owns it
    }

    // MARK: - Attitude → aim

    /// Last well-defined azimuth, held across the zenith singularity where
    /// the back normal has no horizontal projection. Single-queue access
    /// (serial motion queue) → no race.
    nonisolated(unsafe) private static var lastAzimuth: Double = 0

    /// Convert a Core Motion attitude into the horizon-frame aim (azimuth +
    /// altitude) the projection speaks. Two device axes matter:
    ///
    ///   • TOP edge (device +Y) — the "reading / pointing" axis: tilted
    ///     back, it points at the patch of sky in front of you and rises as
    ///     you lift the phone.
    ///   • BACK normal (−device +Z) — the camera axis: held flat UP to the
    ///     sky it points at the stars overhead.
    ///
    /// AZIMUTH comes from the BACK NORMAL alone, ALTITUDE from a blend of
    /// the two by posture ("screen-down-ness", −m33). Why split them:
    ///
    ///   The top edge sweeps *through the zenith* as the phone passes the
    ///   upright pose — and at the zenith azimuth flips 180° (N↔S). Reading
    ///   azimuth off a blend that's top-weighted there made the whole canvas
    ///   double-flip on the way up and read 180°-inverted after (point south,
    ///   sky shows north). The back normal instead stays on the facing
    ///   bearing the entire raise (it rises within the facing vertical plane,
    ///   never crossing to the far azimuth), so its horizontal projection is
    ///   a stable heading. Only when the phone is flat overhead does the back
    ///   normal reach the zenith and lose its bearing — there altitude ≈ 90°
    ///   (cone collapses to the puck, heading-up is moot), so we just hold
    ///   the last azimuth. Altitude still blends so reading points at the
    ///   front sky and overhead points straight up.
    ///
    /// CONVENTION (resolved on hardware 2026-05-31): Apple's
    /// `attitude.rotationMatrix` maps REFERENCE → device (v_dev = M·v_ref),
    /// so a device axis in reference coords is the matching ROW of M.
    /// Device +Y (top) → row 2 = (m21, m22, m23); device +Z (screen-out) →
    /// row 3 = (m31, m32, m33). Reference frame: X = true north, Y = west,
    /// Z = up. Returns the aim plus the raw screen-down-ness (for the
    /// raise-to-sky trigger).
    private static func sample(from attitude: CMAttitude) -> (aim: Aim, screenDown: Double, pose: Pose?) {
        let m = attitude.rotationMatrix

        // Top edge (device +Y) up-component, back-camera normal (−device +Z)
        // in reference-frame (north, west, up) components.
        let tU = m.m23
        let bN = -m.m31, bW = -m.m32, bU = -m.m33

        // Screen-out normal's downward lean: ~0 upright, →1 held flat
        // overhead (screen facing the user, back to the sky).
        let screenDown = max(0, -m.m33)
        let w = smoothstep(screenDown, lo: aimBlendLo, hi: aimBlendHi)

        // ALTITUDE: blend the two axes' elevations by posture.
        let altitude = asin(max(-1, min(1, (1 - w) * tU + w * bU)))

        // AZIMUTH: back normal's horizontal bearing only (stable through the
        // raise). Hold the last value at the zenith, where it's undefined.
        let horiz = (bN * bN + bW * bW).squareRoot()
        let azimuth: Double
        if horiz > 0.05 {
            azimuth = atan2(-bW, bN)               // clockwise from north
            lastAzimuth = azimuth
        } else {
            azimuth = lastAzimuth
        }

        let aim = Aim(azimuth: quantize(azimuth), altitude: quantize(altitude))
        return (aim, screenDown, smooth(back: SIMD3(bN, bW, bU),
                                        up:   SIMD3(m.m21, m.m22, m.m23)))
    }

    // MARK: - Pose (LOOK mode)

    /// Running low-pass of the pose. Serial motion queue only.
    nonisolated(unsafe) private static var smoothedPose: Pose? = nil

    /// Ease the raw pose toward the last one — renormalised, and `up` kept
    /// square to `back` so the window never shears.
    private static func smooth(back: SIMD3<Double>, up: SIMD3<Double>) -> Pose? {
        guard let last = smoothedPose else {
            smoothedPose = Pose(back: back, up: up)
            return smoothedPose
        }
        let k = poseSmoothing
        let b = simd_normalize(last.back + k * (back - last.back))
        var u = last.up + k * (up - last.up)
        u = u - simd_dot(u, b) * b
        guard simd_length_squared(u) > 1e-12 else { return last }
        let pose = Pose(back: b, up: simd_normalize(u))
        smoothedPose = pose
        return pose
    }

    /// True when the pose moved more than `poseStepDeg` on either axis.
    private static func moved(from old: Pose?, to new: Pose) -> Bool {
        guard let old else { return true }
        let limit = cos(poseStepDeg * .pi / 180)
        return simd_dot(old.back, new.back) < limit || simd_dot(old.up, new.up) < limit
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

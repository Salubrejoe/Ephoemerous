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
            let next = Self.aim(from: motion.attitude)
            // @Observable writes must land on main. We also suppress
            // no-op writes so a still phone leaves the idle Canvas
            // parked (see `ECanvasSchedule`) instead of forcing a
            // 30 Hz redraw of the whole starfield.
            DispatchQueue.main.async {
                if next != self.aim { self.aim = next }
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        aim = nil
    }

    // MARK: - Attitude → aim

    /// Convert a Core Motion attitude into the horizon-frame azimuth +
    /// altitude of the phone's TOP edge (device +Y) — the axis that,
    /// held in a natural "reading" tilt, points along your facing
    /// azimuth and rises into the sky as you lift the top of the phone.
    /// That posture is what the azimuth-led hybrid mapping expects.
    ///
    /// CONVENTION (resolved on hardware 2026-05-31): Apple's
    /// `attitude.rotationMatrix` maps REFERENCE → device (v_dev = M·v_ref),
    /// so a device axis expressed in reference coords is the matching ROW
    /// of M, not the column. Device +Y (top edge) → row 2 =
    /// (m21, m22, m23). The reference frame is X = true north, Y = west,
    /// Z = up.
    ///
    /// The first cut read the column instead (device→reference), which
    /// inverted pitch — tilting the phone up drove the blob *below* the
    /// horizon — and also threw azimuth 180° off. Reading the row fixes
    /// both: lift the top edge and `up = m23 = +sin(tilt)` rises as it
    /// should; top-pointing-north reads azimuth 0.
    private static func aim(from attitude: CMAttitude) -> Aim {
        let m = attitude.rotationMatrix

        // Phone top edge (device +Y) expressed in the reference frame —
        // row 2 of the reference→device matrix.
        let north = m.m21
        let west  = m.m22
        let up    = m.m23

        let altitude = asin(max(-1, min(1, up)))
        let azimuth  = atan2(-west, north)        // clockwise from north

        return Aim(azimuth:  quantize(azimuth),
                   altitude: quantize(altitude))
    }

    /// Round to ~0.5° so magnetometer micro-jitter on a still phone
    /// doesn't publish a fresh value (and wake the idle Canvas) every
    /// single sample. A 0.5° step is invisible under the soft blob.
    private static func quantize(_ radians: Double) -> Double {
        let step = 0.5 * .pi / 180
        return (radians / step).rounded() * step
    }
}

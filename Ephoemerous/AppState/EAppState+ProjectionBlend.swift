import SwiftUI
import simd

// MARK: - EProjectionTransition
// Smooth-stepped blend ∈ [0,1] between the clock (.northSouth) and travel
// (.userLocation) projection frames. Canvas layers read
// `renderedProjectionBlend` (wired in Phase 2) so a mode change animates
// the sky reorienting instead of snapping. Same easing as the date / origin
// transitions — a bounce on a sky rotation looks wrong.
struct EProjectionTransition {
    let fromBlend: Double
    let toBlend:   Double
    let startTime: Double
    let duration:  Double

    private static func smoothStep(_ t: Double) -> Double {
        let t = max(0, min(1, t))
        return t * t * (3 - 2 * t)
    }

    func interpolated(at time: Double) -> Double {
        let t = Self.smoothStep((time - startTime) / duration)
        return fromBlend + (toBlend - fromBlend) * t
    }

    func isFinished(at time: Double) -> Bool {
        time >= startTime + duration
    }
}

// MARK: - EAppState + projection blend
extension EAppState {

    /// 0 = clock frame, 1 = travel frame. The animated value while a
    /// transition is in flight, otherwise the steady value implied by
    /// `appMode`. Self-clears the finished transition on read — same
    /// pattern as `renderedObservationDate`.
    var renderedProjectionBlend: Double {
        let target: Double = appMode == .travel ? 1 : 0
        guard let t = _projectionTransition else { return target }
        if t.isFinished(at: animationTime) {
            _projectionTransition = nil
            return target
        }
        return t.interpolated(at: animationTime)
    }

    /// Kick an animated clock↔travel blend toward `target` (0 or 1).
    /// Phase 4 calls this from the mode toggle.
    func animateProjectionBlend(to target: Double,
                                duration: Double = AstroConstants.transitionDuration) {
        _projectionTransition = EProjectionTransition(
            fromBlend: renderedProjectionBlend,
            toBlend:   target,
            startTime: Date.now.timeIntervalSinceReferenceDate,
            duration:  duration
        )
    }

    // MARK: Camera-slerp frame
    //
    // Phase 0 verdict: clock→travel must MOVE THE CAMERA — slerp the
    // projection centre `.north → originVector` with a parallel-transported
    // basis — NOT spin the sky about a fixed centre. The fixed-centre form
    // drags in-disc stars through the gnomonic horizon (r≈1000); this
    // geodesic form keeps them bounded (≈0.1% leave a clock-sized disc;
    // geodesic ≈39° at the default location).
    //
    // blend 0 is EXACTLY the app's clock frame (centre `.north`, basis
    // `baseVectors(.south)`). blend 1 is the travel centre with the
    // parallel-transported clock basis: the validated *bounded path*.
    // Aligning blend 1 to the app's existing `.userLocation` basis exactly
    // (the in-plane twist + `-Q` / handedness flip) and asserting endpoint
    // exactness against the spike oracle is Phase 2 — deliberately not
    // claimed here.
    func projectionFrame(at blend: Double)
        -> (O: SIMD3<Double>, e1: SIMD3<Double>, e2: SIMD3<Double>) {

        let O0         = SIMD3<Double>.north
        let (e1c, e2c) = SIMD3<Double>.south.baseVectors()
        let O1         = originVector

        let dotv = Swift.min(Swift.max(simd_dot(O0, O1), -1), 1)
        let ang  = acos(dotv) * blend

        var axis = simd_cross(O0, O1)
        if simd_length(axis) < 1e-9 {            // O0 ∥ ±O1 — pick a stable ⟂
            axis = abs(O0.z) < 0.9 ? SIMD3(0, 0, 1) : SIMD3(1, 0, 0)
        }

        return (O0.rotated(about: axis, by: ang),
                e1c.rotated(about: axis, by: ang),
                e2c.rotated(about: axis, by: ang))
    }
}

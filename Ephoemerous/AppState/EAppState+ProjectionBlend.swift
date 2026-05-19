import SwiftUI

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
}

// NOTE: a per-star projection morph (camera-slerp / quaternion frame
// interpolation) was prototyped here in Phase 1 and removed: the spike
// oracle (spikes/projection_frame_spike.swift) proved clock↔travel is a
// ~141° reorientation through a projection blind past 90° — bounded,
// exact, continuous can't all hold. The blend now drives a cross-fade
// between the two whole compositions instead (CelestialCanva).

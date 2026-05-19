import SwiftUI

// MARK: - EProjectionTransition
// A timed defocus envelope for the clock↔travel swap. There is no per-star
// morph (the spike proved it geometrically impossible — see the note at
// the bottom); instead the whole composition is blurred + dimmed, the mode
// is swapped under peak blur, then it sharpens back. `envelope` is 0 at
// rest, 1 at the midpoint (where appMode flips), 0 again at the end.
struct EProjectionTransition {
    let startTime: Double
    let duration:  Double

    private func progress(at time: Double) -> Double {
        max(0, min(1, (time - startTime) / duration))
    }

    /// 0 → 1 → 0, peaking at the midpoint.
    func envelope(at time: Double) -> Double {
        sin(.pi * progress(at: time))
    }

    func isFinished(at time: Double) -> Bool {
        time >= startTime + duration
    }
}

// MARK: - EAppState + mode transition
extension EAppState {

    /// Blur/opacity defocus amount: 0 at rest, peaks 1 mid-swap. Drives the
    /// clock↔travel transition in CelestialCanva. Self-clears the finished
    /// transition on read — same pattern as `renderedObservationDate`.
    var renderedTransitionEnvelope: Double {
        guard let t = _projectionTransition else { return 0 }
        if t.isFinished(at: animationTime) {
            _projectionTransition = nil
            return 0
        }
        return t.envelope(at: animationTime)
    }

    /// Start the defocus envelope. `toggleAppMode` flips the mode at the
    /// midpoint so the hard swap is hidden under peak blur.
    func beginModeTransition(duration: Double = AstroConstants.modeTransitionDuration) {
        _projectionTransition = EProjectionTransition(
            startTime: Date.now.timeIntervalSinceReferenceDate,
            duration:  duration
        )
    }
}

// NOTE: a per-star projection morph (camera-slerp / quaternion frame
// interpolation) was prototyped (Phase 1) and removed: the spike oracle
// proved clock↔travel is a ~141° reorientation through a projection blind
// past 90° — bounded, exact, continuous can't all hold. So the modes are
// swapped under a blur+opacity defocus rather than morphed. Layers also
// self-gate on `appMode`, so a per-layer cross-fade can't work anyway —
// the single atomic swap under peak blur sidesteps that entirely.

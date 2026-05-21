import SwiftUI

// MARK: - EAppState + CanvasClock
// Per-frame bookkeeping the celestial canvas used to do inline: advance the
// animation clock and step any in-flight inertia / origin transitions.
// State writes are dispatched async because the Canvas closure runs inside
// a view update, where synchronous mutation of observed state is illegal.
extension EAppState {

    /// Called once per Canvas frame with the timeline time and canvas size.
    func advanceCanvasClock(to time: Double, canvasSize size: CGSize) {
        animationTime = time
        advanceInertiaTransition(at:  time)
        advanceOriginTransition(at:   time)
        advanceNSOriginTransition(at: time)
        if canvasSize != size {
            DispatchQueue.main.async { self.canvasSize = size }
        }
    }

    private func advanceInertiaTransition(at time: Double) {
        guard var transition = _inertiaTransition else { return }
        let (dx, dy, finished) = transition.advance(to: time)
        let advanced = transition
        DispatchQueue.main.async {
            let proposed = CGPoint(x: self.offset.x + dx, y: self.offset.y + dy)
            let clamped  = self.hardClampedOffset(proposed)
            let hitEdge  = abs(clamped.x - proposed.x) > 0.5
                        || abs(clamped.y - proposed.y) > 0.5
            self.offset = clamped
            // Stop the glide when it reaches the disc edge (no rubber on a fling).
            self._inertiaTransition = (finished || hitEdge) ? nil : advanced
        }
    }

    private func advanceOriginTransition(at time: Double) {
        guard let transition = _originTransition else { return }
        let (lat, lon)  = transition.interpolated(at: time)
        let finished    = transition.isFinished(at: time)
        let updatePlane = transition.updatePlane
        DispatchQueue.main.async {
            self.setOrigin(lat: .radians(lat),
                           lon: .radians(lon),
                           updatePlane: updatePlane)
            if finished {
                self._originTransition = nil
                // Run the completion in the same dispatch as the final
                // setOrigin so any follow-on state flip (e.g. appMode)
                // applies atomically with the final position — avoids
                // the 1–3 frame "phase" race that hit Clock→Travel.
                transition.onCompletion?()
            }
        }
    }

    /// Step the NS origin's spring-back transition. Mirrors
    /// `advanceOriginTransition` but writes directly into `nsOrigin`
    /// (no `setOrigin`-style coupling because the NS projection's plane
    /// is hardcoded to `.south` and never moves with the origin).
    private func advanceNSOriginTransition(at time: Double) {
        guard let transition = _nsOriginTransition else { return }
        let (lat, lon) = transition.interpolated(at: time)
        let finished   = transition.isFinished(at: time)
        DispatchQueue.main.async {
            self.nsOrigin.latitude  = .radians(lat)
            self.nsOrigin.longitude = .radians(lon)
            if finished {
                self._nsOriginTransition = nil
                transition.onCompletion?()
            }
        }
    }
}

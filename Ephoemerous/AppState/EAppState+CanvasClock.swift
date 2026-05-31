import SwiftUI
import LoreKit

// MARK: - EAppState + CanvasClock
// Per-frame bookkeeping the celestial canvas used to do inline: advance the
// animation clock and step any in-flight inertia / origin transitions.
// State writes are dispatched async because the Canvas closure runs inside
// a view update, where synchronous mutation of observed state is illegal.
extension EAppState {

    /// Called once per Canvas frame with the timeline time and canvas size.
    func advanceCanvasClock(to time: Double, canvasSize size: CGSize) {
        animationTime = time
        // First frame after a (de)selection: pin its promotion-spring
        // start to THIS frame's live clock, so the spring's elapsed
        // (`animationTime - _selectionStart`) begins at 0 even though
        // the canvas clock may have been frozen (parked) when the tap
        // landed. Without this the spring sits at 0 until the frozen
        // clock catches up — the seconds-long delay before promotion.
        if _selectionClockPending { _selectionStart = time; _selectionClockPending = false }
        if _deselectClockPending  { _deselectStart  = time; _deselectClockPending  = false }
        // Park the promotion once both springs have settled. Flipping
        // `_promotionActive` false here (not in a computed property that
        // reads `animationTime`) keeps `isAnimating` stable per frame —
        // it changes exactly once, reaching a fixed point, so the body
        // doesn't re-invalidate every tick. Mirrors how `renderedScale`
        // nils a finished `_activeTransition`.
        if _promotionActive {
            let settle = EArtist.shared.poiSelectSettleDuration
            let selSettled   = detailDestination == nil || (time - _selectionStart) >= settle
            let deselSettled = _deselectingID    == nil || (time - _deselectStart) >= settle
            if selSettled && deselSettled { _promotionActive = false }
        }
        advanceInertiaTransition(at: time)
        advanceOriginTransition(at:  time)
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
            // Skip cache invalidation mid-spring. A "return" transition
            // (updatePlane = false, e.g. the two-finger spring-back) ends
            // where it started, so the cache is already correct. A "move"
            // (updatePlane = true) genuinely changes the observer position
            // — invalidate once on the last frame instead of every frame.
            self.setOrigin(lat:              .radians(lat),
                           lon:              .radians(lon),
                           updatePlane:      updatePlane,
                           invalidatesCache: finished && updatePlane)
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

}

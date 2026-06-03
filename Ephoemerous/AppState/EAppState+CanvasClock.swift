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
        // Pan-then-promote: hold the SELECTION spring's start clock until
        // the focus pan has landed, so the label balloons up only AFTER
        // it has arrived rather than while it's still flying across
        // screen. `_activeTransition` is the pan; once it's finished (or
        // there's no pan to wait for) we stamp `_selectionStart = time`
        // so the spring's elapsed begins at 0 right here — no frozen-clock
        // skew (the timeline is already live, running the pan).
        if _selectionClockPending {
            let panDone = _activeTransition.map { $0.isFinished(at: time) } ?? true
            if panDone {
                _selectionStart       = time
                _selectionClockPending = false
            }
        }
        // Deselect has no pan to wait on — start its spring-down at once.
        if _deselectClockPending  { _deselectStart  = time; _deselectClockPending  = false }
        // Park the promotion once both springs have settled. Flipping
        // `_promotionActive` false here (not in a computed property that
        // reads `animationTime`) keeps `isAnimating` stable per frame —
        // it changes exactly once, reaching a fixed point, so the body
        // doesn't re-invalidate every tick. Mirrors how `renderedScale`
        // nils a finished `_activeTransition`.
        if _promotionActive {
            let settle = EArtist.shared.poiSelectSettleDuration
            // A selection whose spring is still PENDING (waiting for the
            // pan to finish) hasn't started — it can't be settled yet, or
            // it would park before ever playing. Once stamped, the
            // elapsed check applies as normal.
            let selSettled = detailDestination == nil
                || (!_selectionClockPending && (time - _selectionStart) >= settle)
            let deselSettled = _deselectingID == nil || (time - _deselectStart) >= settle
            // Clear the deselect id once its spring-down has settled.
            // Without this it stays non-nil forever, so `hasActivePromotion`
            // (selectedObjectID || deselectingID) reads true permanently
            // after the first deselect — making every pan thereafter pay
            // the full promotion cost across all ~300 named stars. The
            // big pan stutter.
            if deselSettled, _deselectingID != nil { _deselectingID = nil }
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

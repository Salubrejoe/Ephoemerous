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

        // Release the per-object pan lock once the focus pan is no longer
        // in flight (transition finished, or none was needed). The pan
        // runs ~0.55s while the detail view's re-pan fires ~1 frame after
        // focus, so the lock is always still held when that redundant
        // second call arrives — then freed here for the next selection.
        if _panningToID != nil, _activeTransition == nil { _panningToID = nil }
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
        // Compass heading low-pass — integrated ONCE per frame here so every
        // reader (canvas snapshot + the rose dial) sees one consistent value,
        // and `renderedRotation` can stay a pure getter. `aim` is delivered
        // at 30 Hz quantized to 0.5°; easing toward it each tick dissolves the
        // steps (and magnetometer jitter) into a glide. dt is clamped so a
        // parked gap can't fling it; tau is the time constant. ▼ TWEAK tau ▼
        if compassMode, let aim = EMotionService.shared.aim {
            let target = -aim.azimuth
            if let cur = _compassRotCurrent {
                let dt  = Swift.min(0.1, Swift.max(0, time - _compassRotTime))
                let tau = 0.10
                let k   = dt > 0 ? (1 - exp(-dt / tau)) : 0
                var delta = (target - cur).truncatingRemainder(dividingBy: 2 * .pi)
                if delta >  .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                _compassRotCurrent = cur + delta * k
            } else {
                // First compass frame: seed from the CURRENT on-screen
                // rotation, NOT the heading, so the low-pass EASES the sky
                // round to the phone's heading instead of snapping — pairing
                // with the zoom-in framing for one smooth entry. `canvasRotation`
                // is `-sky.rotation` (see `mirrorRotationToRose`) and compass
                // `renderedRotation` returns `.radians(_compassRotCurrent)`, so
                // this keeps the camera rotation continuous across the toggle.
                _compassRotCurrent = canvasRotation.radians
            }
            _compassRotTime = time
        } else {
            // Out of compass mode → drop the smoother so a fresh raise snaps
            // to the live heading rather than easing up from a stale value.
            _compassRotCurrent = nil
        }

        // Retire finished camera / rotation transitions HERE rather than
        // lazily inside the rendered* getters. Those getters are read from
        // view bodies that ALSO read these transitions (the rose reads
        // `renderedRotation` + `_rotationTransition`; the canvas reads
        // `renderedScale` + `_activeTransition` via `isAnimating`), so a
        // getter that nils mid-read turns the body into an AttributeGraph
        // cycle → main-thread abort. Cleaning up once per frame in the draw
        // phase (like `_promotionActive` above) keeps the getters pure.
        if let t = _activeTransition,   t.isFinished(at: time) { _activeTransition   = nil }
        if let t = _rotationTransition, t.isFinished(at: time) { _rotationTransition = nil }
        if let t = _dateTransition,     t.isFinished(at: time) { _dateTransition     = nil }

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

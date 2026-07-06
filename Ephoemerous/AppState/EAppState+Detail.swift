import SwiftUI
import LoreKit
import CoreGraphics

// MARK: - EAppState + Detail
// Canvas-tap → detail-sheet behaviour. One destination, one pan, one
// dismiss. Replaces the old EAppState+Sheets.swift (four `present*Info`
// methods, four booleans, four sibling sheets in ObjectsTrackingOverlay).
//
// Apple-Maps model:
//   - `focus(on:)` sets `detailDestination` and animates the canvas so
//     the object lands at the middle of the upper third — i.e. centred
//     in the visible region when the bottom-third sheet is up.
//   - One-shot pan, no zoom change, no snap-back on dismiss.
//   - `dismissDetail()` simply clears the destination; the camera stays
//     where it landed.
extension EAppState {

    // MARK: Public entry points

    /// Open the detail sheet for `obj` and pan to it.
    ///
    /// If a *different* detail is already showing, this routes through
    /// a nil → delay → new sequence rather than assigning straight to
    /// `obj`. SwiftUI's `.sheet(item:)` is documented to dismiss +
    /// represent on identity change, but in practice it often keeps
    /// the `UIPresentationController` alive and only swaps content —
    /// and when it does, the new content's `.presentationDetents`
    /// doesn't always re-apply, so the new sheet ends up at full
    /// height instead of the configured `.fraction(1/3)`. The
    /// two-step forces a clean teardown so the new presentation
    /// reads detents from scratch.
    ///
    /// `_focusEpoch` is bumped on every call (here and in
    /// `dismissDetail()`), and the deferred block aborts if the
    /// epoch has moved on — so a flurry of taps during the dismiss
    /// window settles on the last one rather than racing.
    func focus(on obj: ESkyObject) {
        _focusEpoch &+= 1
        let epoch = _focusEpoch

        // Every selection passes through here, so this is the one place
        // to log Recents — covers canvas taps, search results, and
        // favourites alike, for every object type.
        recordViewed(obj)

        // Something else owns the bottom slot — a scene-editor picker
        // (location / date) or a *different* detail card. SwiftUI presents
        // one sheet per anchor, so selecting an object has to tear that
        // down first, then present after `sheetSwapDelay`. This is the
        // symmetric counterpart to `presentSceneEditor`: pickers override
        // detail, and selecting an object overrides a picker.
        // `_sheetSwapping` suppresses the persistent search sheet across
        // the gap so it doesn't flash in.
        let pickerOpen  = isShowingLocationPicker || isShowingDatePicker
        let otherDetail = detailDestination != nil && detailDestination?.id != obj.id
        if pickerOpen || otherDetail {
            _sheetSwapping          = true
            detailDestination       = nil
            isShowingLocationPicker = false
            isShowingDatePicker     = false
            DispatchQueue.main.asyncAfter(deadline: .now() + sheetSwapDelay) { [weak self] in
                guard let self, self._focusEpoch == epoch else { return }
                self._sheetSwapping    = false
                self.detailDestination = obj
            }
            return
        }

        detailDestination = obj
    }
    // (panTo dropped — the SkyLab comfort-pans off `detailDestination` via
    //  onChange; panTo drove the production camera the SkyLab ignores.)

    /// Pan the camera to `obj` WITHOUT changing the detail
    /// destination — used when an inner navigation (e.g. pushing
    /// from a constellation card to its star) wants the canvas to
    /// follow without dismissing / re-presenting the sheet. Also
    /// called from each detail view's `.onAppear` so a pop-back
    /// from a pushed detail re-pans to the underlying view's
    /// object.
    func panTo(_ obj: ESkyObject) {
        // Per-object dedupe: a fresh selection calls panTo twice — once
        // from focus(on:), once from the detail view's .onAppear a frame
        // later. With the comfort zone the target is position-dependent,
        // so those two calls compute different edge-pans and the
        // target-based dedupe in `animateTo` can't merge them; keying on
        // the OBJECT does. Skip if we're already panning to it.
        if _panningToID == obj.id { return }
        guard let sc = screenPosition(of: obj) else { return }
        _panningToID = obj.id
        panFocus(toward: sc)
    }

    /// Close the detail sheet. Camera stays where the user left it
    /// (intentional — Apple Maps doesn't snap back either). Bumps
    /// the focus epoch so any in-flight deferred `focus(on:)` from
    /// the previous interaction can't bring the sheet back.
    func dismissDetail() {
        _focusEpoch &+= 1
        detailDestination = nil
    }

    // MARK: Myth sheet

    /// Open the half-detent myth sheet for `myth`, dismissing the
    /// detail sheet first if one is up. Same epoch / asyncAfter
    /// dance as `focus(on:)`: SwiftUI's `.sheet(item:)` doesn't
    /// like swapping the *other* sheet in the same frame as
    /// dismissing the current one — the new presentation often
    /// inherits the old detents. Clearing detail, waiting for it
    /// to tear down, then assigning mythDestination forces a clean
    /// re-presentation with `.fraction(0.5)` correctly applied.
    ///
    /// `.none` is a no-op — there's nothing to present.
    func openMyth(_ myth: POIConstellationMyth) {
        guard myth != .none else { return }
        _focusEpoch &+= 1
        let epoch = _focusEpoch

        if detailDestination != nil {
            _sheetSwapping    = true
            detailDestination = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + sheetSwapDelay) { [weak self] in
                guard let self, self._focusEpoch == epoch else { return }
                self._sheetSwapping  = false
                self.mythDestination = myth
            }
            return
        }

        mythDestination = myth
    }

    /// Close the myth sheet. Bumps the focus epoch so any in-flight
    /// deferred opener can't bring a stale destination back.
    func dismissMyth() {
        _focusEpoch &+= 1
        mythDestination = nil
    }

    /// Roughly the iOS sheet dismiss-animation duration — long
    /// enough that the existing sheet has fully torn down before
    /// the new one presents, short enough to feel like a single
    /// fluid swap to the user.
    private var sheetSwapDelay: TimeInterval { 0.35 }

    // MARK: Scene editors (location / date) override the root sheet

    /// Present a scene editor (the location or date picker), making it
    /// take precedence over any open detail / myth sheet.
    ///
    /// A detail / myth sheet and a picker both want the bottom slot, and
    /// SwiftUI presents only one sheet per anchor — so raising a picker
    /// while a detail card is up was silently a no-op. This clears the
    /// root sheet first, then runs `open` once it has torn down (the same
    /// `sheetSwapDelay` dance `focus()` / `openMyth()` use; presenting in
    /// the same frame as the dismiss makes the incoming sheet inherit
    /// stale state). When nothing owns the slot, `open` runs immediately.
    ///
    /// `_sheetSwapping` is held across the teardown so the persistent
    /// search sheet (which would otherwise see "no detail, no picker yet"
    /// and present) doesn't flash in during the gap. `_focusEpoch` is
    /// bumped so an in-flight deferred `focus()` can't resurrect a
    /// destination after we've cleared it.
    func presentSceneEditor(_ open: @escaping () -> Void) {
        _focusEpoch &+= 1
        let hadRootSheet = detailDestination != nil || mythDestination != nil
        guard hadRootSheet else { open(); return }

        _sheetSwapping    = true
        detailDestination = nil
        mythDestination   = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + sheetSwapDelay) { [weak self] in
            guard let self else { return }
            self._sheetSwapping = false
            open()
        }
    }

    // MARK: Screen-position lookup

    /// Where on screen `obj` currently sits, if we know. Falls back to
    /// `nil` for things we don't track per-frame (planets aren't
    /// canvas-tappable yet; list-driven planet focus will need its own
    /// projection helper later).
    private func screenPosition(of obj: ESkyObject) -> CGPoint? {
        switch obj {
        case .sun:
            return sunScreenPosition
        case .moon:
            return moonScreenPosition
        case .star(let star):
            return favouritePositions[ESkyObject.star(star).id] ?? screenPosition(of: star)
        case .constellation(let cons):
            // The label-hit capsule centroid is the natural anchor
            // when the user tapped a constellation label on canvas —
            // it's exactly the rect they touched. But the cache only
            // carries entries for labels currently rendered at text
            // tier, so opens from the search sheet (or any path
            // where the constellation isn't visibly labelled right
            // now) need to project from the anchor RA/Dec directly.
            if let rect = constellationLabelHitRects[cons] {
                return CGPoint(x: rect.midX, y: rect.midY)
            }
            return screenPosition(of: cons)
        case .planet(let planet):
            return planetPositions[planet.name]
        }
    }

    // MARK: Centre-on-object

    /// Apple-Maps "comfort zone" focus. Selecting an object does NOT
    /// zoom — the promotion already forces the label visible at any
    /// scale, so the old zoom-to-text-tier was redundant and (for
    /// deep-tier stars) the source of the heavy 215→432 lurch. We only
    /// nudge the camera, and only when needed:
    ///
    ///   • object already within `comfortRadius` of the focus point →
    ///     no pan at all (just select + promote). Most taps.
    ///   • outside → pan just enough to bring it to the ZONE EDGE (the
    ///     nearest point on the comfort circle), not all the way in —
    ///     minimal motion.
    ///
    /// Scale is left untouched; only the offset moves, through the one
    /// `animateTo` primitive (dedupe + transition live there).
    private func panFocus(toward screenPosition: CGPoint) {
        guard canvasSize != .zero else { return }

        // Comfort-zone centre: the upper-third focus spot (keeps a
        // selected object clear of the bottom detail sheet).
        let focusPoint = CGPoint(x: canvasSize.width / 2,
                                 y: canvasSize.height / 3)
        let dx = screenPosition.x - focusPoint.x
        let dy = screenPosition.y - focusPoint.y
        let dist = (dx * dx + dy * dy).squareRoot()

        // Inside the comfort circle → leave the camera where it is.
        guard dist > comfortRadius else { return }

        // Outside → bring the object only to the circle's edge: the
        // target screen point is `comfortRadius` out from the focus
        // along the object→focus direction.
        let k = comfortRadius / dist
        let edgePoint = CGPoint(x: screenPosition.x - dx * k,
                                y: screenPosition.y - dy * k)
        let newOffset = offsetToCenter(screenPos: screenPosition,
                                       atScale:   scale,
                                       targetX:   edgePoint.x,
                                       targetY:   edgePoint.y)
        animateTo(scale: scale, offset: newOffset)
    }

    /// Radius (pt) of the no-pan comfort zone around the focus point.
    /// Tap an object already inside and the camera stays put. v1: 100.
    private var comfortRadius: CGFloat { 100 }
}

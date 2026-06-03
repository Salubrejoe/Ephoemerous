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

        if let current = detailDestination, current.id != obj.id {
            detailDestination = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + sheetSwapDelay) { [weak self] in
                guard let self, self._focusEpoch == epoch else { return }
                self.detailDestination = obj
                self.panTo(obj)
            }
            return
        }

        detailDestination = obj
        panTo(obj)
    }

    /// Pan the camera to `obj` WITHOUT changing the detail
    /// destination — used when an inner navigation (e.g. pushing
    /// from a constellation card to its star) wants the canvas to
    /// follow without dismissing / re-presenting the sheet. Also
    /// called from each detail view's `.onAppear` so a pop-back
    /// from a pushed detail re-pans to the underlying view's
    /// object.
    func panTo(_ obj: ESkyObject) {
        guard let sc = screenPosition(of: obj) else { return }
        panFocus(toward: sc, minScale: textTierScale(for: obj))
    }

    /// Scale at which `obj`'s on-canvas label reaches its TEXT tier —
    /// i.e. the zoom where you can actually read its name. Focusing
    /// zooms to at least this (with a little headroom past the fade)
    /// so a tapped object never sits below its own label. Reads the
    /// same per-category thresholds the canvas draws with, so the two
    /// can't drift.
    private func textTierScale(for obj: ESkyObject) -> Double {
        let artist = EArtist.shared
        let textIn: Double
        switch obj {
        case .sun:           textIn = artist.poiStyle(for: .sun).textIn
        case .moon:          textIn = artist.poiStyle(for: .moon).textIn
        case .planet(let p): textIn = artist.poiStyle(for: .planet(p)).textIn
        case .star(let s):
            // Match how the star is ACTUALLY drawn: a favourited star
            // renders via FavouritesLayer as `.followedStar` (early
            // thresholds); a plain tapped star stays `.namedStar` in
            // NamedStarsLayer (much later thresholds). Using the wrong
            // one would zoom short of where its label appears.
            let isFavourite = favouriteStars.contains { $0.name == s.name }
            let category: POICategory = isFavourite ? .followedStar(s) : .namedStar(s)
            textIn = artist.poiStyle(for: category).textIn
        case .constellation: textIn = artist.constellationTextIn
        }
        // The tier fade is centred on `textIn`, so clear it by the ramp
        // half-width plus a touch — land where the text is fully in.
        return textIn * 1.2
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
            detailDestination = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + sheetSwapDelay) { [weak self] in
                guard let self, self._focusEpoch == epoch else { return }
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

    // MARK: Pan-only animation

    /// One-shot animated pan + zoom so `screenPosition` lands at
    /// `(canvas.midX, canvas.height / 3)`. Zooms in to at least
    /// `minScale` (never out — if already past it, scale is unchanged),
    /// clamped to the hard zoom ceiling. Uses the same
    /// `EPresetTransition` machinery as the tracking presets so the
    /// canvas renders the lerped scale + offset every frame.
    private func panFocus(toward screenPosition: CGPoint, minScale: Double = 0) {
        guard canvasSize != .zero else { return }
        // "At least" the tier scale: keep the current zoom if already
        // deeper, otherwise pull in to reveal the label. Never exceed
        // the gesture ceiling.
        let targetScale = Swift.min(AstroConstants.maximumScale,
                                    Swift.max(scale, minScale))
        let targetX   = canvasSize.width  / 2
        let targetY   = canvasSize.height / 3
        // offsetToCenter maps the sky point under `screenPosition` to
        // (targetX, targetY) AT `targetScale`, so the object stays put
        // as the zoom ramps.
        let newOffset = offsetToCenter(screenPos: screenPosition,
                                       atScale:   targetScale,
                                       targetX:   targetX,
                                       targetY:   targetY)
        _activeTransition = EPresetTransition(
            fromScale:  renderedScale,
            fromOffset: renderedOffset,
            toScale:    targetScale,
            toOffset:   newOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        scale  = targetScale
        offset = newOffset
    }
}

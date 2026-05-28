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
    func focus(on obj: ESkyObject) {
        detailDestination = obj
        guard let sc = screenPosition(of: obj) else { return }
        panFocus(toward: sc)
    }

    /// Close the detail sheet. Camera stays where the user left it
    /// (intentional — Apple Maps doesn't snap back either).
    func dismissDetail() {
        detailDestination = nil
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
            // The label-hit capsule centroid is the natural anchor —
            // it's what the user just tapped.
            guard let rect = constellationLabelHitRects[cons] else { return nil }
            return CGPoint(x: rect.midX, y: rect.midY)
        case .planet(let planet):
            return planetPositions[planet.name]
        }
    }

    // MARK: Pan-only animation

    /// One-shot animated pan so `screenPosition` lands at
    /// `(canvas.midX, canvas.height / 3)`. Scale unchanged — only the
    /// offset moves. Uses the same `EPresetTransition` machinery as the
    /// tracking presets so the canvas renders the lerped offset every
    /// frame.
    private func panFocus(toward screenPosition: CGPoint) {
        guard canvasSize != .zero else { return }
        let targetX   = canvasSize.width  / 2
        let targetY   = canvasSize.height / 3
        let newOffset = offsetToCenter(screenPos: screenPosition,
                                       atScale:   scale,
                                       targetX:   targetX,
                                       targetY:   targetY)
        _activeTransition = EPresetTransition(
            fromScale:  renderedScale,
            fromOffset: renderedOffset,
            toScale:    scale,                       // unchanged — no auto-zoom
            toOffset:   newOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        offset = newOffset
    }
}

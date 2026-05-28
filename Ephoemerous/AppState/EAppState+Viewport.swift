import SwiftUI

// MARK: - EAppState + Viewport bounds
// Map-like rule: the screen viewport stays inside the projected sky
// disc (the alt = 0 great-circle image at the current scale).
//
// The disc has radius `scale · clipRadius` and is centred at
// screenCentre + offset (offset.y = horizontal shift, offset.x = vertical —
// see EGraphicContext.toScreen). Per axis the pan room is:
//
//     maxOffset = max(0, discRadius − halfScreen)
//
//   • disc ≤ screen (zoomed out) → 0: the disc stays centred (nothing
//     beyond it to pan to anyway).
//   • disc > screen (zoomed in)  → discRadius − halfScreen, which GROWS
//     with scale, so you can roam inside the visible-sky circle — more
//     room the further you zoom. (The earlier abs() shrank this toward
//     0 as you zoomed in, locking everything to centre.)
extension EAppState {

    func contentDiscRadius(atScale s: Double) -> Double {
        s * EArtist.shared.clipRadius * 2
    }

    /// Per-axis `|offset|` limit, or nil when panning should be free.
    func viewportOffsetLimits(forScale s: Double) -> (x: Double, y: Double)? {
        guard canvasSize.width  > 0,
              canvasSize.height > 0,
              s.isFinite else { return nil }
        // `defaultScale` is the home detent: at or below it the clock is
        // framed by design, so there is no resting position other than
        // `defaultOffset`. Zero limits → still draggable (rubber), but any
        // pan / zoom-out always springs back home. Roaming the disc is
        // only meaningful once zoomed IN past default.
        if s <= defaultScale { return (x: 0, y: 0) }
        let r = contentDiscRadius(atScale: s)
        return (x: max(0, r - canvasSize.height / 2),
                y: max(0, r - canvasSize.width  / 2))
    }

    func viewportOffsetLimits() -> (x: Double, y: Double)? {
        viewportOffsetLimits(forScale: renderedScale)
    }

    // Pan room is centred on `defaultOffset` (the watch's designed resting
    // position), NOT screen-centre — so zoomed out it parks at the real
    // home, and zoomed in you roam ± lim around it.
    func hardClampedOffset(_ o: CGPoint, atScale s: Double) -> CGPoint {
        guard let lim = viewportOffsetLimits(forScale: s) else { return o }
        let c = defaultOffset
        return CGPoint(x: c.x + Swift.min(Swift.max(o.x - c.x, -lim.x), lim.x),
                       y: c.y + Swift.min(Swift.max(o.y - c.y, -lim.y), lim.y))
    }

    func hardClampedOffset(_ o: CGPoint) -> CGPoint {
        hardClampedOffset(o, atScale: renderedScale)
    }
}

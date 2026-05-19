import SwiftUI

// MARK: - EAppState + Viewport bounds
// Map-like rule: the screen viewport stays inside the content disc.
//
// The clock disc has radius `scale · clipRadius` and is centred at
// screenCentre + offset (offset.y = horizontal shift, offset.x = vertical —
// see EGraphicContext.toScreen). Per axis the pan room is:
//
//     maxOffset = max(0, discRadius − halfScreen)
//
//   • disc ≤ screen (zoomed out) → 0: the watch face stays centred (there
//     is nothing beyond the disc to pan to anyway).
//   • disc > screen (zoomed in)  → discRadius − halfScreen, which GROWS
//     with scale, so you can roam around inside the clock circle — more
//     room the further you zoom. (The earlier abs() shrank this toward 0
//     as you zoomed in, locking everything to centre.)
//
// Travel mode has no finite disc, so panning there is left unbounded.
extension EAppState {

    func contentDiscRadius(atScale s: Double) -> Double {
        s * EArtist.shared.clipRadius * 2
    }

    /// Per-axis `|offset|` limit, or nil when panning should be free.
    func viewportOffsetLimits(forScale s: Double) -> (x: Double, y: Double)? {
        guard appMode == .clock,
              canvasSize.width  > 0,
              canvasSize.height > 0,
              s.isFinite else { return nil }
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

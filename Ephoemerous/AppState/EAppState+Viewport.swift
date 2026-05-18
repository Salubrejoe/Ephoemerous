import SwiftUI

// MARK: - EAppState + Viewport bounds
// Map-like rule: the screen viewport stays inside the content disc.
//
// The clock disc has radius `scale · clipRadius` and is centred at
// screenCentre + offset (offset.y = horizontal shift, offset.x = vertical —
// see EGraphicContext.toScreen). Per axis, the furthest you may shift before
// the screen edge would pass the disc edge is:
//
//     maxOffset = | discRadius − halfScreen |
//
//   • disc bigger than the screen → r − half  (pan inside, never show void)
//   • disc smaller than the screen → half − r (disc stays fully on screen)
//
// Travel mode has no finite disc, so panning there is left unbounded.
extension EAppState {

    func contentDiscRadius(atScale s: Double) -> Double {
        s * ENSWatchCrownLayer.clipRadius
    }

    /// Per-axis `|offset|` limit, or nil when panning should be free.
    func viewportOffsetLimits(forScale s: Double) -> (x: Double, y: Double)? {
        guard appMode == .clock,
              canvasSize.width  > 0,
              canvasSize.height > 0,
              s.isFinite else { return nil }
        let r = contentDiscRadius(atScale: s)
        return (x: abs(r - canvasSize.height / 2),
                y: abs(r - canvasSize.width  / 2))
    }

    func viewportOffsetLimits() -> (x: Double, y: Double)? {
        viewportOffsetLimits(forScale: renderedScale)
    }

    func hardClampedOffset(_ o: CGPoint, atScale s: Double) -> CGPoint {
        guard let lim = viewportOffsetLimits(forScale: s) else { return o }
        return CGPoint(x: Swift.min(Swift.max(o.x, -lim.x), lim.x),
                       y: Swift.min(Swift.max(o.y, -lim.y), lim.y))
    }

    func hardClampedOffset(_ o: CGPoint) -> CGPoint {
        hardClampedOffset(o, atScale: renderedScale)
    }
}

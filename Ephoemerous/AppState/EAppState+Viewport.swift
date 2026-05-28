import SwiftUI

// MARK: - EAppState + Viewport bounds
//
// Two-zone rule for offset clamping:
//
//   • s < defaultScale  → full rubber-band home. Limits are (0, 0),
//     so any pan or zoom-out drags hit the rubber immediately and
//     `settleWithinBounds` springs the view back to `defaultOffset`.
//     This is the "launch detent" feel — the user is below the anchor
//     zoom and the canvas wants to re-frame the disc.
//
//   • s ≥ defaultScale → free pan. Limits return `nil`, so
//     `rubberOffset` and `hardClampedOffset` short-circuit and the
//     view stays exactly where the user releases. The canvas extends
//     past the projected horizon disc (below-horizon wash + ambient
//     grid live there) so there's actual content to roam to.
//
// `defaultScale` is canvas-derived (see EAppState+Space.swift) so the
// anchor zoom always frames the horizon to the device's shorter side.
extension EAppState {

    func contentDiscRadius(atScale s: Double) -> Double {
        s * EArtist.shared.clipRadius * 2
    }

    /// Per-axis `|offset|` limit, or nil when panning should be free.
    func viewportOffsetLimits(forScale s: Double) -> (x: Double, y: Double)? {
        guard canvasSize.width  > 0,
              canvasSize.height > 0,
              s.isFinite else { return nil }
        // Below the anchor zoom: rubber pulls everything home.
        // At or above: free pan, no rubber.
        return s < defaultScale ? (x: 0, y: 0) : nil
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

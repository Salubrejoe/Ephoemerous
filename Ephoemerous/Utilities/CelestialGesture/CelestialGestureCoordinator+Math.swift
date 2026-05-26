import SwiftUI

// MARK: - CelestialGestureCoordinator + Math
// Single source of truth for the screen⇄sky mapping every zoom uses.
// Mirrors EGraphicContext.toScreen: offset.y is the horizontal shift,
// offset.x the vertical. Both pinch and double-tap-hold reuse these so
// a sky point pinned at gesture start lands under the same screen point
// at any new scale.
extension CelestialGestureCoordinator {

    func skyPoint(under screen: CGPoint, state: EAppState) -> CGPoint {
        let size = state.canvasSize
        return CGPoint(
            x: (screen.x - size.width  / 2 - state.offset.y) / state.scale,
            y: (size.height / 2 + state.offset.x - screen.y) / state.scale
        )
    }

    /// Offset that puts `sky` exactly under screen point `p` at `scale`.
    func screenPin(sky: CGPoint, under p: CGPoint, scale: Double,
                   state: EAppState) -> CGPoint {
        let size = state.canvasSize
        return CGPoint(
            x: p.y - size.height / 2 + sky.y * scale,
            y: p.x - size.width  / 2 - sky.x * scale
        )
    }

    /// Order- and NaN-safe scale clamp. Floor = defaultScale but never
    /// above the hard ceiling; ceiling = maximumScale.
    func clampScale(_ candidate: Double, state: EAppState) -> Double {
        let df    = state.defaultScale
        let floor = df.isFinite ? Swift.min(df, maximumScale) : 1
        guard candidate.isFinite else { return floor }
        return Swift.min(Swift.max(candidate, floor), maximumScale)
    }

    /// Zoom-out reset. While the raw (pre-rubber) scale is pulled below
    /// `defaultScale` — the zoom-out rubber zone — blend the offset home
    /// toward `defaultOffset` in step with how far it's pulled. So pinching
    /// or hold-dragging all the way out lands on the exact initial view
    /// (default scale AND offset), not just the initial scale. f = 0 at
    /// the floor (offset stays pinned), → 1 as the scale is pulled toward 0.
    func homedTowardDefault(_ pinned: CGPoint, rawScale: Double,
                            state: EAppState) -> CGPoint {
        let floor = state.defaultScale.isFinite
            ? Swift.min(state.defaultScale, maximumScale) : 1
        guard rawScale.isFinite, rawScale < floor, floor > 0 else { return pinned }
        let f = Swift.min(Swift.max((floor - rawScale) / floor, 0), 1)
        let d = state.defaultOffset
        return CGPoint(x: pinned.x + (d.x - pinned.x) * f,
                       y: pinned.y + (d.y - pinned.y) * f)
    }
}

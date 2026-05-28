import SwiftUI

// MARK: - CelestialGestureCoordinator + Math
// Single source of truth for the screen⇄sky mapping every zoom uses.
// Mirrors EGraphicContext.toScreen: offset.y is the horizontal shift,
// offset.x the vertical. Both pinch and double-tap-hold reuse these so
// a sky point pinned at gesture start lands under the same screen point
// at any new scale.
extension CelestialGestureCoordinator {

    /// Screen pixel → projection-unit point. Exact inverse of
    /// `EGraphicContext.toScreen`. When `state.canvasRotation != 0`
    /// the plain projection-space result is un-rotated so pan/pinch
    /// math stays in sky coordinates regardless of how the device
    /// is held.
    func skyPoint(under screen: CGPoint, state: EAppState) -> CGPoint {
        let size = state.canvasSize
        let plain = CGPoint(
            x: (screen.x - size.width  / 2 - state.offset.y) / state.scale,
            y: (size.height / 2 + state.offset.x - screen.y) / state.scale
        )
        if state.canvasRotation == .zero { return plain }
        let θ    = state.canvasRotation.radians
        let cosθ = cos(θ)
        let sinθ = sin(θ)
        // Rotate by -θ to undo toScreen's forward rotation.
        return CGPoint(x:  plain.x * cosθ + plain.y * sinθ,
                       y: -plain.x * sinθ + plain.y * cosθ)
    }

    /// Offset that puts `sky` (projection coords) exactly under
    /// screen point `p` at `scale`. Applies the canvas rotation
    /// forward so the pin holds when the device is rotated.
    func screenPin(sky: CGPoint, under p: CGPoint, scale: Double,
                   state: EAppState) -> CGPoint {
        let size = state.canvasSize
        let skyRot: CGPoint
        if state.canvasRotation == .zero {
            skyRot = sky
        } else {
            let θ    = state.canvasRotation.radians
            let cosθ = cos(θ)
            let sinθ = sin(θ)
            skyRot = CGPoint(x: sky.x * cosθ - sky.y * sinθ,
                             y: sky.x * sinθ + sky.y * cosθ)
        }
        return CGPoint(
            x: p.y - size.height / 2 + skyRot.y * scale,
            y: p.x - size.width  / 2 - skyRot.x * scale
        )
    }

    /// Order- and NaN-safe scale clamp. Floor and ceiling are the
    /// gesture-coordinator's `minimumScale` / `maximumScale` — both
    /// independent of `state.defaultScale` (which is *launch* scale,
    /// not a hard limit). `state` is kept on the signature for
    /// symmetry with other math helpers in this extension.
    func clampScale(_ candidate: Double, state: EAppState) -> Double {
        guard candidate.isFinite else { return minimumScale }
        return Swift.min(Swift.max(candidate, minimumScale), maximumScale)
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

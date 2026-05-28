import SwiftUI
import LoreKit

// MARK: - CelestialGestureCoordinator + Rubber
// Rubber-band resistance past the viewport offset disc and the scale floor /
// ceiling, plus the post-gesture `settleWithinBounds` spring-back. The pure
// damping curve itself lives in LoreKit (`Double.rubberBanded(limit:dim:c:)`);
// these helpers wire that math to canvas-specific limits.
extension CelestialGestureCoordinator {

    /// Offset with rubber resistance past the map-like disc limits.
    func rubberOffset(_ raw: CGPoint, state: EAppState,
                      scale s: Double) -> CGPoint {
        guard let lim = state.viewportOffsetLimits(forScale: s) else { return raw }
        // Resist relative to defaultOffset (the home), not screen-centre.
        let c = state.defaultOffset
        return CGPoint(
            x: c.x + (raw.x - c.x).rubberBanded(limit: lim.x,
                                                 dim: state.canvasSize.height,
                                                 c: rubberC),
            y: c.y + (raw.y - c.y).rubberBanded(limit: lim.y,
                                                 dim: state.canvasSize.width,
                                                 c: rubberC)
        )
    }

    /// Scale with damped overshoot past floor / ceiling (springs back on
    /// release). Built from the same UIScrollView damping curve as
    /// `rubberOffset`, just with the asymmetric "ceiling" vs "floor" room
    /// the zoom interaction wants: a little headroom above the ceiling, a
    /// generous (45 %) cushion under the floor for the zoom-out reset.
    /// Floor / ceiling are `minimumScale` / `maximumScale` — the
    /// gesture-coordinator's hard limits, independent of `defaultScale`
    /// (which is *launch* scale, not a clamp).
    func rubberScale(_ raw: Double, state: EAppState) -> Double {
        let ceiling = maximumScale
        let floor   = minimumScale
        guard raw.isFinite else { return floor }
        if raw > ceiling {
            let over = raw - ceiling
            return ceiling + (1 - 1 / (over * rubberC / ceiling + 1)) * (ceiling * scaleOvershootFraction)
        }
        if raw < floor {
            let over = floor - raw
            return floor - (1 - 1 / (over * rubberC / floor + 1)) * (floor * 0.45)
        }
        return raw
    }

    /// On gesture end: if scale/offset overshot, spring back to the exact
    /// limits via the shared preset transition (its bounce reads as "edge").
    func settleWithinBounds(state: EAppState) {
        let targetScale  = clampScale(state.scale, state: state)
        let targetOffset = state.hardClampedOffset(state.offset, atScale: targetScale)
        let dScale  = abs(targetScale - state.scale)
        let dOffset = hypot(targetOffset.x - state.offset.x,
                            targetOffset.y - state.offset.y)
        guard dScale > 0.01 || dOffset > 0.5 else { return }
        state._activeTransition = EPresetTransition(
            fromScale:  state.renderedScale,
            fromOffset: state.renderedOffset,
            toScale:    targetScale,
            toOffset:   targetOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        state.scale  = targetScale
        state.offset = targetOffset
    }
}

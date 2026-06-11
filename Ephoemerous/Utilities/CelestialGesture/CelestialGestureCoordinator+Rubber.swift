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

    /// Scale with a progressive SPRING past floor / ceiling — no hard wall.
    ///
    /// The old curve saturated (displayed overshoot asymptoted to a fixed
    /// fraction), so once you reached it pinching did nothing — a wall. This
    /// one works in LOG space (zoom is multiplicative, so the resistance
    /// reads the same zooming in and out) and maps the over-limit distance
    /// through `ln(1 + k·over) / k`: it keeps growing without bound but with
    /// ever-diminishing returns, so you can always pinch a little further —
    /// it just gets stiffer and stiffer. Continuous and C¹ at the limit
    /// (derivative 1 there → no kink). `k` = `scaleRubberStiffness` sets the
    /// stiffness; on release `settleWithinBounds` springs back to the exact
    /// limit. Floor / ceiling are the gesture's hard limits
    /// (`minimumScale` / `maximumScale`), independent of `defaultScale`.
    func rubberScale(_ raw: Double, state: EAppState) -> Double {
        let ceiling = maximumScale
        let floor   = minimumScale
        guard raw.isFinite, raw > 0 else { return floor }

        let k  = scaleRubberStiffness
        let L  = log(raw)
        let Lc = log(ceiling)
        let Lf = log(floor)

        if L > Lc {                       // past the zoom-in ceiling
            let over = L - Lc
            return exp(Lc + log(1 + k * over) / k)
        }
        if L < Lf {                       // past the zoom-out floor
            let over = Lf - L
            return exp(Lf - log(1 + k * over) / k)
        }
        return raw
    }

    /// On gesture end: if scale/offset overshot, spring back to the exact
    /// limits via the shared preset transition (its bounce reads as "edge").
    func settleWithinBounds(state: EAppState) {
        let targetScale = clampScale(state.scale, state: state)

        // Re-pin the screen CENTRE across the scale spring-back. During an
        // over-zoom the offset was set to hold the finger-anchor at the
        // rubber scale; simply clamping it and snapping the scale back
        // resizes around the projection origin (the zenith), which reads as
        // a pan. Instead, keep whatever sky point sits at the centre now
        // fixed as the scale settles to the limit → the over-zoom just
        // resizes in place. When only the offset overshot (scale unchanged)
        // this round-trips to the current offset, so the disc spring-back is
        // unaffected.
        let size      = state.canvasSize
        let centre    = CGPoint(x: size.width / 2, y: size.height / 2)
        let centreSky = skyPoint(under: centre, state: state)
        let repinned  = screenPin(sky: centreSky, under: centre,
                                  scale: targetScale, state: state)
        let targetOffset = state.hardClampedOffset(repinned, atScale: targetScale)

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

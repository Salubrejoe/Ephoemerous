import SwiftUI
import LoreKit

// MARK: - POI label tier transitions
//
// Tiers used to pop in/out at a hard `renderedScale` threshold.
// Instead each tier's opacity + scale ramps as a smooth function
// of scale, centred on its old threshold, so a label eases in as
// you pinch toward it and eases back out as you pinch away — the
// transition tracks the gesture rather than snapping.
extension EArtist {

    /// Width of a tier's fade/scale ramp, as a fraction of its
    /// threshold. Narrow enough to feel responsive to a pinch, wide
    /// enough to read as an ease rather than a pop.
    var labelTierRampFraction: Double { 0.18 }

    /// Scale a tier grows through as it appears — from this floor up
    /// to 1. Subtle on purpose: the eye should read "settling in",
    /// not "zooming".
    var labelTierScaleFloor: CGFloat { 0.82 }

    /// Eased 0→1 appearance for a tier whose hard cut-off was
    /// `threshold`: 0 below the ramp, 1 above it, smoothstep across a
    /// band centred on `threshold`. A non-positive threshold means
    /// "always on" (the sun / moon badge) → fully present.
    func labelTierProgress(scale: Double, threshold: Double) -> Double {
        guard threshold > 0 else { return 1 }
        let band = labelTierRampFraction * threshold
        let t    = (scale - (threshold - band / 2)) / band
        let c    = min(max(t, 0), 1)
        return c * c * (3 - 2 * c)            // smoothstep
    }

    /// Map an eased tier progress to its scale factor.
    func labelTierScale(_ progress: Double) -> CGFloat {
        labelTierScaleFloor + (1 - labelTierScaleFloor) * CGFloat(progress)
    }

    // MARK: - Zoom-dynamic label size

    /// Continuous zoom response for POI label TEXT. Once a label's tier
    /// has revealed it, the font no longer locks to a fixed size — it
    /// breathes with the map (smaller zoomed out, larger zoomed in), the
    /// same "scale dynamic" feel the promoted pin has. Cheap: it's just a
    /// scalar on the text scale the label already applies — no new font,
    /// no extra draws, and only the few dozen visible labels pay it.
    ///
    /// Anchored at the default scale (factor 1.0, so the resting look is
    /// unchanged), eased between these bounds at the zoom extremes. Same
    /// two-anchor shape as `magnitudeCap` / the puck size curve.
    var poiTextZoomMinFactor: CGFloat { 0.9 }   // toward the zoom-out floor
    var poiTextZoomMaxFactor: CGFloat { 1.3 }   // toward the zoom-in ceiling

    func poiTextZoomFactor(forScale scale: Double) -> CGFloat {
        let floorScale   = 25.0
        let defaultScale = AstroConstants.defaultScale
        let ceilScale    = AstroConstants.maximumScale

        if scale <= floorScale { return poiTextZoomMinFactor }
        if scale >= ceilScale  { return poiTextZoomMaxFactor }

        if scale <= defaultScale {
            let t = CGFloat((scale - floorScale) / (defaultScale - floorScale))
            return poiTextZoomMinFactor + (1 - poiTextZoomMinFactor) * t
        }
        let t = CGFloat((scale - defaultScale) / (ceilScale - defaultScale))
        return 1 + (poiTextZoomMaxFactor - 1) * t
    }
}

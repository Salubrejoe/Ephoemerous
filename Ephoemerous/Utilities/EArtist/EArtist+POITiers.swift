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
}

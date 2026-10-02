import SwiftUI
import LoreKit

// MARK: - Named stars
// Thresholds for the proper-named-star POI tier. The layer-level gate
// (`namedStarDotIn`) sits ABOVE constellation tier 2 (their textIn = 190)
// so the canvas doesn't go from "constellation names just appeared" to
// "constellation names + every named star dot" in one zoom step — there's
// a small dead zone where the user has constellation names but no star
// labels yet, by design.
//
// `namedStarTapMinScale` mirrors `labelTapMinScale` on constellations:
// tap targets only get published once the badge itself is visible, so a
// tier-0 dot can't ambush a pinch-to-zoom.
extension Artist {

    /// Rendered scale at which named-star tier-0 dots start to appear.
    /// Constellation labels hit tier 2 (text) at scale 190; this is
    /// 30 above so the user gets a clean "constellation reading" zoom
    /// range before the star-label layer kicks in.
    var namedStarDotIn:       Double { 220 }

    /// Rendered scale at which named-star tap targets are published.
    /// Matches the `.namedStar` tier-0 `badgeIn` in `poiStyle(for:)` so
    /// taps land exactly when the first badges appear.
    var namedStarTapMinScale: Double { 280 }

    // MARK: - Reveal cascade (brightness ripple)
    //
    // The named-star LABELS surface brightest-first, each at its OWN zoom:
    // the delay slides smoothly with magnitude, so pinching in reads as a
    // ripple — Sirius, then Vega, then Capella… — instead of three waves of
    // labels popping together. (It was three discrete tiers; within a tier
    // every star still appeared at once.)
    //
    // Only the badge/text thresholds ripple, NOT the dot: every named star
    // shows its tier-0 dot together at `namedStarDotIn`, so a dimmer star
    // just holds its dot a little longer until its badge arrives — nothing
    // blinks out in the gap. `poiTier(for:)` reads these.

    /// The brightest named stars' badge + text reveal scales.
    var namedStarBadgeIn:  Double { 280 }
    var namedStarTextIn:   Double { 360 }
    /// Magnitudes the ripple runs across: at or brighter than the first,
    /// no delay; at or fainter than the second, the full delay.
    var namedStarRippleBrightest: Double { 0.0 }
    var namedStarRippleFaintest:  Double { 4.0 }
    /// Zoom added to both thresholds at the faint end of the ripple — the
    /// same total spread the three tiers had (2 × 140).
    var namedStarRippleSpan:      Double { 280 }

    /// How much later than the brightest a star of `magnitude` reveals.
    func namedStarRevealDelay(magnitude: Double) -> Double {
        let t = (magnitude - namedStarRippleBrightest) / (namedStarRippleFaintest - namedStarRippleBrightest)
        return min(1, max(0, t)) * namedStarRippleSpan
    }
}

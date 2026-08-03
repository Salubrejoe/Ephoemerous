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

    // MARK: - Reveal cascade (brightness tiers)
    //
    // The named-star LABELS surface brightest-first. Three magnitude tiers,
    // each revealing its badge + text a step later in the zoom, so the
    // headline stars (Sirius, Vega, Arcturus…) name themselves before the
    // fainter named stars join in — a brightness-ordered ripple as you
    // pinch in, instead of every label popping at one threshold.
    //
    // Only the badge/text thresholds are tiered, NOT the dot: every named
    // star still shows its tier-0 dot together at `namedStarDotIn`, so a
    // dimmer star just holds its dot a little longer until its badge
    // cascades in — nothing blinks out in the gap. `poiStyle(for:)` reads
    // these for the `.namedStar` case.

    /// Tier-0 (brightest) badge + text reveal scales. Dimmer tiers offset
    /// later by `namedStarTierStep` each.
    var namedStarBadgeIn:  Double { 280 }
    var namedStarTextIn:   Double { 360 }
    /// Added to both thresholds per dimmer tier (tier index × step) — the
    /// zoom gap between successive brightness waves.
    var namedStarTierStep: Double { 140 }
    /// Magnitude cuts between the three tiers (magnitude ascends ⇒ dimmer).
    var namedStarTier1Cut: Double { 1.6 }   // tier 0 | tier 1
    var namedStarTier2Cut: Double { 2.8 }   // tier 1 | tier 2

    /// Reveal tier for a named star: 0 = brightest (first), 2 = faintest
    /// (last). Pure function of apparent magnitude.
    func namedStarTier(magnitude: Double) -> Int {
        if magnitude < namedStarTier1Cut { return 0 }
        if magnitude < namedStarTier2Cut { return 1 }
        return 2
    }
}

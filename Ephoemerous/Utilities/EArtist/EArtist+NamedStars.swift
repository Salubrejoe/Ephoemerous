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
extension EArtist {

    /// Rendered scale at which named-star tier-0 dots start to appear.
    /// Constellation labels hit tier 2 (text) at scale 190; this is
    /// 30 above so the user gets a clean "constellation reading" zoom
    /// range before the star-label layer kicks in.
    var namedStarDotIn:       Double { 220 }

    /// Rendered scale at which named-star tap targets are published.
    /// Matches the `.namedStar` `badgeIn` in `poiStyle(for:)` so taps
    /// land exactly when there's a badge to aim at.
    var namedStarTapMinScale: Double { 280 }
}

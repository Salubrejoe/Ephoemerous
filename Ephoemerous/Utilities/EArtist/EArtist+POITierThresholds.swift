import Foundation

// MARK: - POI tier thresholds
// The zoom thresholds that gate every POI label — the ONE place to tune
// when a badge (tier 0 → 1) and its name (tier 1 → 2) fade in as the user
// pinches. `poiStyle(for:)` reads these into each `POICategoryStyle`; the
// named-star case delegates to the brightness-tiered constants in
// `EArtist+NamedStars.swift`.
//
// Values are RENDERED SCALE (the map's zoom factor, ~90 at the default
// view). Lower = appears sooner; `badgeIn: 0` = always shown.
/// Rendered-scale gates for one category: the badge fades in at `badgeIn`,
/// the name at `textIn`. Top-level (like `POICategory` / `POIDotShape`) so
/// call sites resolve it without an `EArtist.` prefix.
struct POITier {
    let badgeIn: Double
    let textIn:  Double
}

extension EArtist {

    /// The `.followedStar` gates, reachable without a star in hand (the
    /// tier map below ignores the payload). The iPad zoom floor anchors
    /// on its `textIn` so favourite names survive a full zoom-out — see
    /// `northInMinScale` in MainView😇.
    var followedStarTier: POITier { POITier(badgeIn: 100, textIn: 120) }

    /// The tier map — tweak every category's reveal timing here.
    func poiTier(for category: POICategory) -> POITier {
        switch category {
        // Top-priority bodies: always badged, name just below the floor.
        case .sun, .moon:     return POITier(badgeIn: 0,   textIn: 50)
        // Constellations lead the reading order.
        case .constellation:  return POITier(badgeIn: 130, textIn: 190)
        // A tapped/followed star sits early so it's easy to re-find.
        case .followedStar:   return followedStarTier
        // Planets bloom from their tier-0 dot only once zoomed in.
        case .planet:         return POITier(badgeIn: 160, textIn: 220)
        // Named stars cascade in brightest-first, well past
        // constellation-name territory (see `EArtist+NamedStars`).
        case .namedStar(let star):
            let bump = Double(namedStarTier(magnitude: star.magnitude)) * namedStarTierStep
            return POITier(badgeIn: namedStarBadgeIn + bump,
                           textIn:  namedStarTextIn  + bump)
        }
    }
}

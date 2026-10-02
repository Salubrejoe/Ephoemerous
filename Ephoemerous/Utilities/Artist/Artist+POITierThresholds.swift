import Foundation
import CoreGraphics

// MARK: - POI tier thresholds
// The zoom thresholds that gate every POI label — the ONE place to tune
// when a badge (tier 0 → 1) and its name (tier 1 → 2) fade in as the user
// pinches. `poiStyle(for:)` reads these into each `POICategoryStyle`; the
// named-star case delegates to the brightness-tiered constants in
// `Artist+NamedStars.swift`.
//
// Values are RENDERED SCALE (the map's zoom factor, ~90 at the default
// view). Lower = appears sooner; `badgeIn: 0` = always shown.
/// Rendered-scale gates for one category: the badge fades in at `badgeIn`,
/// the name at `textIn`. Top-level (like `POICategory` / `POIDotShape`) so
/// call sites resolve it without an `Artist.` prefix.
struct POITier {
    let badgeIn: Double
    let textIn:  Double
}

extension Artist {

    /// The `.followedStar` gates, reachable without a star in hand (the
    /// tier map below ignores the payload). The iPad zoom floor anchors
    /// on its `textIn` so favourite names survive a full zoom-out — see
    /// `northInMinScale` in MainView😇.
    var followedStarTier: POITier { POITier(badgeIn: 100, textIn: 120) }

    /// Rendered scale at which a figure star's bare Bayer letter appears
    /// (`BayerLabels`). Not a `POICategory` — there is no badge and no tap
    /// target, only the glyph — but it belongs on this dial with the rest.
    ///
    /// LAST thing on the map to arrive. The named-star cascade finishes at
    /// 640 (`namedStarTextIn` + `namedStarRippleSpan`) and the pinch
    /// ceiling is 1200, so this sits in the final third: every star that
    /// has a name has said it before a single Greek letter shows up.
    ///
    /// It was 420 first, which put the letters in the MIDDLE of that
    /// cascade — they landed while stars were still naming themselves, and
    /// on iPad (which rests at a higher scale than the phone, so it reaches
    /// any absolute threshold sooner) that read as noise almost at rest.
    ///
    /// One flat threshold, no brightness cascade — these are all faint by
    /// definition, so there is no headline order to stagger. ▼ TWEAK ▼
    var bayerLetterIn: Double { 800 }

    // MARK: Label comfort zone  ▼ TWEAK ▼  (see `LabelComfortZone`)
    /// The calm middle where unpromoted names may show, as a fraction of
    /// the visible window — a squircle this wide and this tall.
    var labelComfortWidth:   CGFloat { 0.78 }
    var labelComfortHeight:  CGFloat { 0.72 }
    /// The outer share of that squircle over which names fade out.
    var labelComfortFeather: CGFloat { 0.18 }

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
        // Spacecraft ride the planet tier — same zoom, lowest declutter
        // priority (see `SpacecraftLabels`).
        case .spacecraft:     return POITier(badgeIn: 160, textIn: 220)
        // Named stars ripple in brightest-first, each at its own zoom, well
        // past constellation-name territory (see `Artist+NamedStars`).
        case .namedStar(let star):
            let delay = namedStarRevealDelay(magnitude: star.magnitude)
            return POITier(badgeIn: namedStarBadgeIn + delay,
                           textIn:  namedStarTextIn  + delay)
        }
    }
}

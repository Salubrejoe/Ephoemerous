import SwiftUI
import LoreKit

// MARK: - POI styling
// Maps a `POICategory` to its visual `POICategoryStyle` (palette,
// sizing, zoom thresholds) and holds the badge-level tuning knobs
// shared across every POI label. Drawing lives in
// `EArtist+POILabel.swift`.
extension EArtist {

    /// Visual style for one POI category. Centralised so palette
    /// tweaks land in one file.
    struct POICategoryStyle {
        let gradientTop:     Color
        let gradientBottom:  Color
        let border:          Color
        let symbolColor:     Color
        let textColor:       Color
        let badgeSize:       CGFloat
        let symbolPointSize: CGFloat
        /// Number of squircle corners — each category carries its
        /// own polygon so you can tell tracked-object classes apart
        /// at a glance (constellations square, stars pentagonal,
        /// sun hex, moon triangular, planets heptagonal).
        let badgeCorners:    Int
        /// Shape used for the tier-0 dot marker.
        let dotShape:        POIDotShape
        /// Radius of the tier-0 marker (circle radius / squircle
        /// half-extent).
        let dotRadius:       CGFloat
        /// Renderered-scale at which the badge appears (tier 0 → 1).
        let badgeIn:         Double
        /// Renderered-scale at which the text appears (tier 1 → 2).
        let textIn:          Double
    }

    /// Apple-Maps-faithful palette. Constellations get purple
    /// (cultural / info), followed stars get warm gold, every
    /// solar-system body carries its own tint — sun warm, moon
    /// cool, each planet matched to its canonical colour.
    func poiStyle(for category: POICategory) -> POICategoryStyle {
        // Solar-system bodies share thresholds; corners + gradient
        // vary per body (sun = hex, moon = triangle).
        func solarStyle(top: Color, bottom: Color, corners: Int) -> POICategoryStyle {
            POICategoryStyle(
                gradientTop:     top,
                gradientBottom:  bottom,
                border:          .systemBackground,
                symbolColor:     .systemBackground,
                textColor:       .primary,
                badgeSize:       22,
                symbolPointSize: 11,
                badgeCorners:    corners,
                dotShape:        .circle,
                dotRadius:       2.5,
                badgeIn:         0,    // always badge — top-priority bodies
                textIn:          50    // crisp name well below the zoom floor
            )
        }

        func moonStyle(top: Color, bottom: Color, corners: Int) -> POICategoryStyle {
            POICategoryStyle(
                gradientTop:     top,
                gradientBottom:  bottom,
                border:          .systemBackground,
                symbolColor:     .white,
                textColor:       .primary,
                badgeSize:       18,
                symbolPointSize: 9,
                badgeCorners:    corners,
                dotShape:        .circle,
                dotRadius:       2.5,
                badgeIn:         0,    // always badge — top-priority bodies
                textIn:          50    // crisp name well below the zoom floor
            )
        }

        func planetStyle(top: Color, bottom: Color) -> POICategoryStyle {
            POICategoryStyle(
                gradientTop:     top,
                gradientBottom:  bottom,
                border:          .systemBackground,
                symbolColor:     .systemBackground,
                textColor:       top,
                badgeSize:       11,
                symbolPointSize: 6,
                badgeCorners:    4,    // heptagon
                dotShape:        .circle,
                dotRadius:       2.5,
                // Above the default scale (90) so a planet reads as a small
                // tier-0 dot at rest and only blooms into its badge + name
                // once the user zooms in — Sun/Moon (badgeIn 0) stay the only
                // labelled bodies on the default view.
                badgeIn:         160,
                textIn:          220
            )
        }

        // Shared knobs for every constellation kind — only the
        // gradient differs by kind, and within a kind by dec.
        func constellationStyle(top: Color, bottom: Color) -> POICategoryStyle {
            POICategoryStyle(
                gradientTop:     top,
                gradientBottom:  bottom,
                border:          .systemBackground,
                symbolColor:     .systemBackground,
                textColor:       .primary,
                badgeSize:       10,
                symbolPointSize: 6,
                badgeCorners:    4,    // rounded square
                dotShape:        .circle,
                dotRadius:       1.0,  // smaller — constellations recede at low zoom
                badgeIn:         130,
                textIn:          190
            )
        }

        switch category {
        case .constellation(let kind):
            let g = constellationGradient(kind: kind)
            return constellationStyle(top: g.top, bottom: g.bottom)
        case .followedStar(let star):
            // Tint the badge to the star's spectral class — O blue,
            // M red, etc. The two-mode colour pair on EHRClass
            // gives us a natural light → deep ramp for the gradient.
            let g = star.spectralClass.badgeGradient
            return POICategoryStyle(
                gradientTop:     .bodySunBottom,
                gradientBottom:  .bodySunTop,
                border:          .systemBackground,
                symbolColor:     .systemBackground,
                textColor:       g.top,
                badgeSize:       12,
                symbolPointSize: 6,
                badgeCorners:    5,    // pentagon — star
                dotShape:        .squircle(corners: 5, bulge: poiBadgeBulge),
                dotRadius:       2.5,
                badgeIn:         70,
                textIn:          120
            )
        case .namedStar(let star):
            // Same pentagon silhouette + spectral palette as the
            // followed-star badge so a named star reads as the same
            // visual species — but the thresholds land much later in
            // the zoom range, so the dot/badge/text only kick in when
            // the user is clearly past constellation-name territory.
            // Selecting one promotes it to `.followedStar` (which has
            // the early thresholds + favourite heart).
            //
            // Brightness cascade: the badge + text reveal scales are
            // pushed later for dimmer stars (3 tiers), so the brightest
            // named stars label themselves first. The dot threshold
            // (`namedStarDotIn`) stays shared, so dimmer stars hold their
            // dot until their badge catches up — see `EArtist+NamedStars`.
            let g    = star.spectralClass.badgeGradient
            let tier = namedStarTier(magnitude: star.magnitude)
            let bump = Double(tier) * namedStarTierStep
            return POICategoryStyle(
                gradientTop:     .bodySunBottom,
                gradientBottom:  .bodySunTop,
                border:          .systemBackground,
                symbolColor:     .systemBackground,
                textColor:       g.top,
                badgeSize:       12,
                symbolPointSize: 6,
                badgeCorners:    5,    // pentagon — star
                dotShape:        .squircle(corners: 5, bulge: poiBadgeBulge),
                dotRadius:       2.0,  // slightly smaller than followedStar
                badgeIn:         namedStarBadgeIn + bump,   // tier 0 = 280
                textIn:          namedStarTextIn  + bump    // tier 0 = 360
            )
        case .sun:
            return solarStyle(
                top:     palette.sun.bottom,
                bottom:  palette.sun.top,
                corners: 12     // hexagon
            )
        case .moon:
            return moonStyle(
                top:     palette.moon.bottom,
                bottom:  palette.moon.top,
                corners: 3     // triangle
            )
        case .planet(let p):
            let g = planetGradient(p)
            return planetStyle(
                top: g.bottom,
                bottom: g.top
            )
        }
    }

    /// Resolve the (top, bottom) badge gradient for a constellation
    /// kind. `foreverInvisible` overrides with a recessive gray;
    /// everything else dispatches to the myth palette defined in
    /// `EArtist+ConstellationMyth.swift` — that's where to tweak
    /// colours per myth cycle.
    func constellationGradient(kind: POIConstellationKind) -> (top: Color, bottom: Color) {
        switch kind {
        case .foreverInvisible:
            return constellationForeverInvisibleGradient
        case .myth(let myth):
            return constellationMythGradient(myth)
        }
    }

    /// Squircle bulge shared by every badge — corner count is
    /// per-category, see `POICategoryStyle.badgeCorners`.
    var poiBadgeBulge: CGFloat { 3.9 }
    /// Horizontal gap between the badge's right edge and the text's
    /// left edge — keeps the pill from feeling crowded.
    var poiTextLeadingGap: CGFloat { 6 }
    /// Shadow under the badge — a tight halo in the canvas colour so
    /// the pill lifts off the sky as one shape.
    var poiShadow: GraphicsContext.Filter {
        .shadow(color: .systemBackground,
                radius: 1, x: 0, y: 1)
    }
}

import SwiftUI
import LoreKit

// MARK: - POI styling
// Maps a `POICategory` to its visual `POICategoryStyle` (palette, sizing,
// dot shape) and holds the badge-level tuning knobs shared across every
// POI label. The zoom thresholds live in `Artist+POITierThresholds.swift`;
// drawing lives in `Artist+POILabel.swift`.
extension Artist {

    /// Visual style for one POI category. Centralised so palette tweaks
    /// land in one file. Only the fields that vary per category are
    /// required — `border`, `dotShape` and `dotRadius` carry shared
    /// defaults.
    struct POICategoryStyle {
        /// Badge fill — a bright centre (`gradientTop`) fading to a deep
        /// rim (`gradientBottom`), so the pill reads as a little orb.
        let gradientTop:    Color
        let gradientBottom: Color
        /// Colour of the name label below the badge.
        let textColor:      Color
        /// Badge diameter (pt).
        let badgeSize:      CGFloat
        /// Squircle corner count — each category carries its own polygon
        /// so you can tell tracked-object classes apart at a glance
        /// (stars pentagonal, moon triangular, sun near-circular…).
        let badgeCorners:   Int
        /// Tier-0 dot marker — the shape + radius the POI collapses to
        /// below `badgeIn`. Default is a plain 2.5-pt circle.
        let dotShape:       POIDotShape
        let dotRadius:      CGFloat
        /// Zoom thresholds — see `poiTier(for:)` in
        /// `Artist+POITierThresholds.swift`, the one place to tune them.
        let tier:           POITier

        /// Casing colour shared by every badge — the light outline that
        /// reads against a busy sky. One source of truth for all categories,
        /// and for the marks that aren't badges either (the favourite heart)
        /// — see `Artist.poiBadgeCasing`.
        var border: Color { Artist.shared.poiBadgeCasing }
        /// Rendered-scale at which the badge appears (tier 0 → 1).
        var badgeIn: Double { tier.badgeIn }
        /// Rendered-scale at which the name appears (tier 1 → 2).
        var textIn:  Double { tier.textIn }

        init(gradientTop:    Color,
             gradientBottom: Color,
             textColor:      Color,
             badgeSize:      CGFloat,
             badgeCorners:   Int,
             tier:           POITier,
             dotShape:       POIDotShape = .circle,
             dotRadius:      CGFloat     = 2.5) {
            self.gradientTop    = gradientTop
            self.gradientBottom = gradientBottom
            self.textColor      = textColor
            self.badgeSize      = badgeSize
            self.badgeCorners   = badgeCorners
            self.tier           = tier
            self.dotShape       = dotShape
            self.dotRadius      = dotRadius
        }
    }

    /// Apple-Maps-faithful palette. Constellations get purple (cultural /
    /// info), followed stars get their spectral tint, every solar-system
    /// body carries its own colour — sun warm, moon cool, each planet
    /// matched to its canonical hue.
    func poiStyle(for category: POICategory) -> POICategoryStyle {
        let tier = poiTier(for: category)

        switch category {
        case .constellation:
            // One neutral indigo→purple tint for every constellation (the
            // myth-colour taxonomy is retired). Recedes fast at low zoom,
            // so a tiny 1-pt dot.
            let g = constellationGradient
            return POICategoryStyle(
                gradientTop:    g.top,
                gradientBottom: g.bottom,
                textColor:      .primary,
                badgeSize:      10,
                badgeCorners:   4,          // rounded square
                tier:           tier,
                dotRadius:      1.0)

        case .followedStar(let star):
            // Tinted to the star's spectral class (O blue … M red) — the
            // two-mode pair on `HRClass` gives a light→deep ramp. Dot is a
            // tiny pentagon so the silhouette already reads as a star.
            let g = star.spectralClass.badgeGradient
            return POICategoryStyle(
                gradientTop:    g.top,
                gradientBottom: g.bottom,
                textColor:      g.bottom,
                badgeSize:      12,
                badgeCorners:   5,          // pentagon — star
                tier:           tier,
                dotShape:       .squircle(corners: 5, bulge: poiBadgeBulge))

        case .namedStar(let star):
            // Same pentagon + spectral palette as a followed star (reads as
            // the same species), just a slightly smaller dot. Its late
            // thresholds live in the tier map. Selecting one promotes it to
            // `.followedStar`.
            let g = star.spectralClass.badgeGradient
            return POICategoryStyle(
                gradientTop:    g.top,
                gradientBottom: g.bottom,
                textColor:      g.bottom,
                badgeSize:      12,
                badgeCorners:   5,          // pentagon — star
                tier:           tier,
                dotShape:       .squircle(corners: 5, bulge: poiBadgeBulge),
                dotRadius:      2.0)

        case .sun:
            // Warm palette, near-circular badge; gradient runs deep→bright
            // (top/bottom swapped) so the centre glows.
            return POICategoryStyle(
                gradientTop:    palette.sun.bottom,
                gradientBottom: palette.sun.top,
                textColor:      .white,
                badgeSize:      22,
                badgeCorners:   12,         // near-circle
                tier:           tier)

        case .moon:
            return POICategoryStyle(
                gradientTop:    palette.moon.bottom,
                gradientBottom: palette.moon.top,
                textColor:      .white,
                badgeSize:      18,
                badgeCorners:   3,          // triangle
                tier:           tier)

        case .planet(let p):
            // Each planet matched to its canonical tint; the name inherits
            // the badge's rim colour.
            let g = planetGradient(p)
            return POICategoryStyle(
                gradientTop:    g.bottom,
                gradientBottom: g.top,
                textColor:      g.bottom,
                badgeSize:      11,
                badgeCorners:   4,
                tier:           tier)
        }
    }

    /// Single neutral tint for every constellation badge. The myth-colour
    /// taxonomy is retired (hemisphere-neutral — southern constellations
    /// have no Greek cycle), so all constellations read as one "cultural /
    /// info" species. ▼ TWEAK the constellation colour here ▼
    var constellationGradient: (top: Color, bottom: Color) {
        // LoreKit's Color wrappers, not `Color(.systemIndigo)` — the
        // UIColor spelling doesn't exist on watchOS; the wrapper carries
        // a literal fallback there and the same UIKit value on iOS.
        (Color.systemIndigo, Color.systemPurple)
    }

    /// Squircle bulge shared by every badge — corner count is
    /// per-category, see `POICategoryStyle.badgeCorners`.
    var poiBadgeBulge: CGFloat { 3.9 }

    /// The dark casing every POI mark wears. Lives here (not on the
    /// per-category style) so non-badge marks — the favourite heart — can
    /// speak the same grammar. ▼ TWEAK the casing here ▼
    var poiBadgeCasing: Color { .black.opacity(0.9) }
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

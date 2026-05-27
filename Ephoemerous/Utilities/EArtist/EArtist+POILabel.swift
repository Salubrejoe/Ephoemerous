import SwiftUI
import LoreKit

// MARK: - POI labels
// Unified Apple-Maps-style label primitive used by every tracked
// celestial object — constellation labels, followed-star labels,
// solar-system labels (sun / moon / planets).
//
// Each `drawPOILabel(…)` call resolves a `POICategoryStyle` from
// the object's `POICategory` (palette + sizing + thresholds) and
// rolls through three zoom tiers:
//
//   tier 0 (scale < badgeIn) — nothing (or a category-tinted dot
//                              if `drawDot: true`, for objects
//                              with no underlying rendering)
//   tier 1 (badgeIn..textIn) — squircle badge + glyph
//   tier 2 (scale ≥ textIn)  — badge + text label below
//
// The badge is centred on the projected screen position so any
// other rendering the layer drew at the same spot (sun glow,
// breathing halo, …) reads as "behind" the badge.

enum POIGlyph {
    /// SF Symbol drawn via `Image(systemName:)`. Use for "named"
    /// glyphs Apple ships (sun, moon, star, sparkles, etc.).
    case sfSymbol(String)
    /// Raw Unicode character drawn via `Text`. Use for the
    /// astronomical planet glyphs (☿ ♀ ♂ ♃ ♄ ♅ ♆) which SF
    /// Symbols doesn't ship.
    case unicode(String)
}

/// Visibility / cultural tier driving the constellation badge palette.
/// Resolved per-frame from the constellation's centroid declination,
/// the observer's latitude, and a static zodiac lookup — see
/// `ConstellationNamesLayer`.
enum POIConstellationKind {
    /// Never rises at the observer's latitude. Muted gray.
    case foreverInvisible
    /// Never sets at the observer's latitude. Teal.
    case circumpolar
    /// One of the IAU 13 ecliptic constellations (incl. Ophiuchus). Blue.
    case zodiac
    /// Rises and sets seasonally. Default purple.
    case standard
}

enum POICategory {
    /// Carries the kind (palette tier) and the centroid declination
    /// in degrees. The declination drives a per-constellation hue
    /// rotation on top of the kind's base palette, so each label
    /// reads as a unique-by-position member of its tier.
    case constellation(POIConstellationKind, dec: Double)
    case followedStar(EStar)
    case sun
    case moon
    case planet(EPlanet)
}

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
                badgeSize:       18,
                symbolPointSize: 9,
                badgeCorners:    corners,
                badgeIn:         0,    // always badge — top-priority bodies
                textIn:          80
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
                badgeIn:         0,    // always badge — top-priority bodies
                textIn:          80
            )
        }

        func planetStyle(top: Color, bottom: Color) -> POICategoryStyle {
            POICategoryStyle(
                gradientTop:     top,
                gradientBottom:  bottom,
                border:          .systemBackground,
                symbolColor:     .systemBackground,
                textColor:       .primary,
                badgeSize:       16,
                symbolPointSize: 8,
                badgeCorners:    6,    // heptagon
                badgeIn:         80,
                textIn:          130
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
                badgeSize:       12,
                symbolPointSize: 6,
                badgeCorners:    4,    // rounded square
                badgeIn:         130,
                textIn:          190
            )
        }

        switch category {
        case .constellation(let kind, let dec):
            let g = constellationGradient(kind: kind, dec: dec)
            return constellationStyle(top: g.top, bottom: g.bottom)
        case .followedStar(let star):
            // Tint the badge to the star's spectral class — O blue,
            // M red, etc. The two-mode colour pair on EHRClass
            // gives us a natural light → deep ramp for the gradient.
            let g = star.spectralClass.badgeGradient
            return POICategoryStyle(
                gradientTop:     g.top,
                gradientBottom:  g.bottom,
                border:          .primary,
                symbolColor:     .systemBackground,
                textColor:       .primary,
                badgeSize:       18,
                symbolPointSize: 9,
                badgeCorners:    5,    // pentagon — star
                badgeIn:         70,
                textIn:          120
            )
        case .sun:
            return solarStyle(
                top:     Color(red: 1.00, green: 0.83, blue: 0.30),
                bottom:  Color(red: 0.95, green: 0.45, blue: 0.10),
                corners: 8     // hexagon
            )
        case .moon:
            return moonStyle(
                top:     Color(red: 0.92, green: 0.94, blue: 1.00),
                bottom:  Color(red: 0.55, green: 0.62, blue: 0.78),
                corners: 7     // triangle
            )
        case .planet(let p):
            let g = planetGradient(p)
            return planetStyle(top: g.top, bottom: g.bottom)
        }
    }

    /// HSB-based constellation gradient with a small per-constellation
    /// hue rotation driven by the centroid declination — so two
    /// constellations of the same kind don't read as identical.
    /// Each kind picks a (baseHue, top saturation/brightness,
    /// bottom saturation/brightness); dec rotates the hue by up to
    /// ±`hueRange` at the celestial poles. Grays use saturation 0
    /// so their "rotation" is invisible but the rest of the kinds
    /// shift through neighbouring tints.
    func constellationGradient(
        kind: POIConstellationKind,
        dec:  Double
    ) -> (top: Color, bottom: Color) {
        // (baseHue 0…1, hueRange 0…1, sTop, bTop, sBot, bBot)
        let (h, dh, sT, bT, sB, bB): (Double, Double, Double, Double, Double, Double) = {
            switch kind {
            case .foreverInvisible:
                return (0.0,  0.0,  0.0, 0.62, 0.0, 0.32)
            case .circumpolar:
                return (0.6, 0.01, 0.95, 0.90, 0.85, 0.55)
            case .zodiac:
                return (0.89, 0.01, 0.60, 0.95, 0.85, 0.60)
            case .standard:
                return (0.78, 0.06, 0.50, 0.85, 0.75, 0.50)
            }
//            return (0.0,  0.0,  0.0, 0.62, 0.0, 0.32)
        }()
        let normDec = max(-1.0, min(1.0, dec / 90.0))
        // `+ 1` then mod 1 keeps the hue in [0, 1) for negative dec
        // shifts (Swift's `truncatingRemainder` returns the same
        // sign as the dividend).
        let hue = (h + normDec * dh + 1.0).truncatingRemainder(dividingBy: 1.0)
        return (
            top:    Color(hue: hue, saturation: sT, brightness: bT),
            bottom: Color(hue: hue, saturation: sB, brightness: bB)
        )
        
//        return (
//            top: .quaternaryLabel,
//            bottom: .tertiary
//        )
    }

    /// Squircle bulge shared by every badge — corner count is
    /// per-category, see `POICategoryStyle.badgeCorners`.
    var poiBadgeBulge: CGFloat { 2.6 }
    /// Horizontal gap between the badge's right edge and the text's
    /// left edge — keeps the pill from feeling crowded.
    var poiTextLeadingGap: CGFloat { 5 }
    /// Shadow under both the badge and the trailing text — same
    /// envelope so the pill reads as one shape.
    var poiShadow: GraphicsContext.Filter {
        .shadow(color: .black.opacity(0.22),
                radius: 2.5, x: 0, y: 1.2)
    }

    /// Draws an Apple-Maps-style POI label at `sc`.
    ///
    /// - `glyph`: SF Symbol name or Unicode glyph for the inner badge.
    /// - `text`: the label below the badge (tier 2).
    /// - `category`: drives palette + thresholds.
    /// - `drawDot`: at tier 0, draw a small category-tinted dot
    ///   when `true`. Use for objects with no other rendering at
    ///   the same screen position — only constellations need this
    ///   today (sun / moon / stars / planets already have visuals).
    func drawPOILabel(
        at sc: CGPoint,
        glyph: POIGlyph,
        text: String,
        category: POICategory,
        drawDot: Bool = false,
        in dc: inout EGraphicContext
    ) {
        let style = poiStyle(for: category)
        let scale = dc.renderedScale

        // Tier 0 — maybe-dot.
        if scale < style.badgeIn {
            if drawDot {
                let r: CGFloat = 2.5
                dc.ctx.fill(
                    Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r,
                                           width: 2 * r, height: 2 * r)),
                    with: .color(style.gradientBottom))
            }
            return
        }

        // Tier 1 — squircle badge.
        let badgeRect = CGRect(
            x: sc.x - style.badgeSize / 2,
            y: sc.y - style.badgeSize / 2,
            width:  style.badgeSize,
            height: style.badgeSize
        )
        let badgePath = Squircle(corners: style.badgeCorners,
                                 bulge:   poiBadgeBulge)
            .path(in: badgeRect)

        // Apple-Maps-style soft drop shadow under the badge. Scoped
        // to a local context so the filter doesn't leak onto the
        // glyph drawn next (the text below gets its own shadowed
        // context so the pill reads as a single shape under one
        // shadow envelope).
        var shadowed = dc.ctx
        shadowed.addFilter(poiShadow)
        let gradient = Gradient(colors: [style.gradientTop, style.gradientBottom])
        shadowed.fill(
            badgePath,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: badgeRect.midX, y: badgeRect.minY),
                endPoint:   CGPoint(x: badgeRect.midX, y: badgeRect.maxY)
            )
        )
        shadowed.stroke(badgePath,
                        with: .color(style.border),
                        lineWidth: 0.5)

        // Glyph inside the badge. Wrapping `Image(systemName:)` in
        // `Text` lets us route both branches through the same
        // `ctx.draw(Text, at:, anchor:)` overload (Image alone doesn't
        // accept `.font` / `.foregroundStyle`).
        let glyphText: Text
        let glyphSize: CGFloat
        switch glyph {
        case .sfSymbol(let name):
            glyphText = Text(Image(systemName: name))
            glyphSize = style.symbolPointSize
        case .unicode(let str):
            // Astronomical glyphs render a touch smaller than SF
            // Symbols at the same point size, so bump them slightly.
            glyphText = Text(str)
            glyphSize = style.symbolPointSize + 2
        }
        dc.ctx.draw(
            glyphText
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(style.symbolColor),
            at:     CGPoint(x: badgeRect.midX, y: badgeRect.midY),
            anchor: .center
        )

        // Tier 2 — text trailing to the right of the badge.
        //
        // The text picks up the same vertical gradient the badge
        // uses (lighter top, darker bottom) and the same drop
        // shadow, so badge + text read as a single Apple-Maps-style
        // pill instead of two stacked elements.
        guard scale >= style.textIn else { return }
        let textGradient = LinearGradient(
            colors:     [style.gradientTop, style.gradientBottom],
            startPoint: .top,
            endPoint:   .bottom
        )
        var textCtx = dc.ctx
        textCtx.addFilter(poiShadow)
        textCtx.draw(
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textGradient),
            at:     CGPoint(x: badgeRect.maxX + poiTextLeadingGap,
                            y: sc.y),
            anchor: .leading
        )
    }
}

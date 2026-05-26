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

enum POICategory {
    case constellation
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
        // Shared knobs for every solar-system body.
        func solarStyle(top: Color, bottom: Color) -> POICategoryStyle {
            POICategoryStyle(
                gradientTop:     top,
                gradientBottom:  bottom,
                border:          .primary,
                symbolColor:     .systemBackground,
                textColor:       .primary,
                badgeSize:       18,
                symbolPointSize: 12,
                badgeIn:         0,    // always badge — top-priority bodies
                textIn:          80
            )
        }

        switch category {
        case .constellation:
            return POICategoryStyle(
                gradientTop:     Color(red: 0.71, green: 0.49, blue: 0.86),
                gradientBottom:  Color(red: 0.42, green: 0.29, blue: 0.72),
                border:          .primary,
                symbolColor:     .systemBackground,
                textColor:       .primary,
                badgeSize:       12,
                symbolPointSize: 11,
                badgeIn:         80,
                textIn:          130
            )
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
                symbolPointSize: 11,
                badgeIn:         60,
                textIn:          100
            )
        case .sun:
            return solarStyle(
                top:    Color(red: 1.00, green: 0.83, blue: 0.30),
                bottom: Color(red: 0.95, green: 0.45, blue: 0.10)
            )
        case .moon:
            return solarStyle(
                top:    Color(red: 0.92, green: 0.94, blue: 1.00),
                bottom: Color(red: 0.55, green: 0.62, blue: 0.78)
            )
        case .planet(let p):
            let g = planetGradient(p)
            return solarStyle(top: g.top, bottom: g.bottom)
        }
    }

    /// Squircle parameters shared by every badge. Tweak here.
    var poiBadgeCorners: Int     { 12 }
    var poiBadgeBulge:   CGFloat { 2.0 }
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
        let badgePath = Squircle(corners: poiBadgeCorners,
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

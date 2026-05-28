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

/// Shape for the tier-0 "dot" marker — what the POI collapses to
/// when zoomed below `badgeIn`. Most categories want a plain
/// circle; followed stars want a tiny pentagon-squircle so the
/// silhouette already reads as a star at the smallest scale.
enum POIDotShape {
    case circle
    case squircle(corners: Int, bulge: CGFloat)
}

/// Mythological cycle a constellation belongs to — pulled from
/// `constellation_categories.json` via
/// `EArtist.constellationMyth(of:)`. Drives the badge GRADIENT
/// so a Hercules constellation reads in the same hue as every
/// other Hercules one, a Zodiac one in the zodiac hue, etc.
///
/// Raw values match the strings in the JSON `myths` array — keep
/// in sync if you add a new myth there.
enum POIConstellationMyth: String, CaseIterable {
    case perseus
    case hercules
    case zodiac
    case argo
    case zeus
    case orion
    case orpheus
    /// Constellations with no myth in the JSON (Lacaille / Bayer /
    /// Hevelius modern additions, mostly).
    case none
}

/// What the constellation *depicts* — the JSON `types` axis.
/// Drives the badge SYMBOL (a hero gets `figure.stand`, an animal
/// gets `pawprint.fill`, an instrument gets `ruler.fill`, …), so
/// the silhouette inside the pill tells you "what is this thing"
/// while the colour tells you "what story does it belong to".
///
/// Raw values match the strings in the JSON `types` array.
enum POIConstellationEntity: String, CaseIterable {
    case hero
    case animal
    case creature
    case object
    case instrument
    case deity
    /// Constellations with no `types` entry — falls back to a
    /// generic glyph.
    case none
}

/// Top-level kind for a constellation badge. Either it's never
/// visible to this observer (forever-invisible override → gray),
/// or it carries its myth colour.
enum POIConstellationKind {
    case foreverInvisible
    case myth(POIConstellationMyth)
}

enum POICategory {
    case constellation(POIConstellationKind)
    case followedStar(EStar)
    /// Proper-named star surfaced as a POI at high zoom. Visually a
    /// quieter sibling of `.followedStar` — same pentagon silhouette
    /// and spectral palette, but later thresholds so they only appear
    /// when the user is clearly zoomed in. Selecting (following) a
    /// named star promotes it to `.followedStar`.
    case namedStar(EStar)
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
                dotShape:        .circle,
                dotRadius:       2.5,
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
                badgeSize:       15,
                symbolPointSize: 8,
                badgeCorners:    6,    // heptagon
                dotShape:        .circle,
                dotRadius:       2.5,
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
                gradientTop:     g.top,
                gradientBottom:  g.bottom,
                border:          .systemBackground,
                symbolColor:     .systemBackground,
                textColor:       .primary,
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
            // the breathing halo + early thresholds).
            let g = star.spectralClass.badgeGradient
            return POICategoryStyle(
                gradientTop:     g.top,
                gradientBottom:  g.bottom,
                border:          .systemBackground,
                symbolColor:     .systemBackground,
                textColor:       .primary,
                badgeSize:       12,
                symbolPointSize: 6,
                badgeCorners:    5,    // pentagon — star
                dotShape:        .squircle(corners: 5, bulge: poiBadgeBulge),
                dotRadius:       2.0,  // slightly smaller than followedStar
                badgeIn:         280,  // well past constellation textIn (190)
                textIn:          360
            )
        case .sun:
            return solarStyle(
                top:     Color(red: 1.00, green: 0.83, blue: 0.30),
                bottom:  Color(red: 0.95, green: 0.45, blue: 0.10),
                corners: 12     // hexagon
            )
        case .moon:
            return moonStyle(
                top:     .gray,
                bottom:  .black,
                corners: 3     // triangle
            )
        case .planet(let p):
            let g = planetGradient(p)
            return planetStyle(top: g.top, bottom: g.bottom)
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
    var poiBadgeBulge: CGFloat { 2.8 }
    /// Horizontal gap between the badge's right edge and the text's
    /// left edge — keeps the pill from feeling crowded.
    var poiTextLeadingGap: CGFloat { 5 }
    /// Shadow under both the badge and the trailing text — same
    /// envelope so the pill reads as one shape.
    var poiShadow: GraphicsContext.Filter {
        .shadow(color: .systemBackground,
                radius: 1, x: 0, y: 0)
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

        // Tier 0 — maybe-dot. Shape (circle / squircle) and radius
        // come from the category style so a followed star
        // collapses to a tiny pentagon rather than a plain dot.
        if scale < style.badgeIn {
            if drawDot {
                let r    = style.dotRadius
                let rect = CGRect(x: sc.x - r, y: sc.y - r,
                                  width: 2 * r, height: 2 * r)
                let path: Path
                switch style.dotShape {
                case .circle:
                    path = Path(ellipseIn: rect)
                case .squircle(let corners, let bulge):
                    path = Squircle(corners: corners, bulge: bulge).path(in: rect)
                }
                dc.ctx.fill(path, with: .color(style.gradientBottom))
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
//        textCtx.draw(
//            Text(text)
////                .font(.footnote.weight(.bold))
//                .font(.system(size: 10, weight: .bold))
//                .foregroundStyle(Color.systemBackground),
//            at:     CGPoint(x: badgeRect.maxX + poiTextLeadingGap,
//                            y: sc.y),
//            anchor: .leading
//        )
        textCtx.draw(
            Text(text)
                .font(.footnote.weight(.bold))
//                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(textGradient),
            at:     CGPoint(x: badgeRect.maxX + poiTextLeadingGap,
                            y: sc.y),
            anchor: .leading
        )
        
    }
}

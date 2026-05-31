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
/// `EArtist.constellationMyth(of:)`. Drives the badge GRADIENT so
/// a Hercules constellation reads in the same hue as every other
/// Hercules one, an Orion one in the hunter hue, etc.
///
/// Raw values match the strings in the JSON `myths` array — keep
/// in sync if you add a new myth there.
///
/// Note: the former `.zodiac` case is gone. The zodiac is a *band
/// of sky*, not a myth cycle — each of its 12+1 constellations has
/// its own narrative home (e.g. Aries → Argo / Golden Fleece;
/// Aquarius → Zeus / Ganymede; Scorpius → Orion).
enum POIConstellationMyth: String, CaseIterable, Identifiable {
    case perseus
    case hercules
    case argo
    case zeus
    case orion
    case orpheus
    /// Constellations with no myth in the JSON (Lacaille / Bayer /
    /// Hevelius modern additions, plus Virgo and Libra whose
    /// classical identifications are too fragmented for a single
    /// cycle).
    case none

    /// Identity is the JSON key. `Identifiable` so the enum can
    /// drive a `.sheet(item:)` binding for `EMythDetailView`.
    var id: String { rawValue }

    /// One-line tagline per cycle — used as the subtitle in
    /// `EMythDetailView` and as the expanded label on the
    /// LearnMyth pill in `DetailActionRow`. Single source of truth
    /// so the two surfaces can never drift out of sync.
    var tagline: String {
        switch self {
        case .perseus:  return "Andromeda and the sea-monster"
        case .hercules: return "The twelve impossible labours"
        case .argo:     return "The voyage for the Golden Fleece"
        case .zeus:     return "The father-god's transformations"
        case .orion:    return "The hunter and the scorpion"
        case .orpheus:  return "The lyre that charmed Hades"
        case .none:     return "Constellation cycle"
        }
    }
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
                badgeSize:       11,
                symbolPointSize: 6,
                badgeCorners:    4,    // heptagon
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
                top:     palette.sun.top,
                bottom:  palette.sun.bottom,
                corners: 12     // hexagon
            )
        case .moon:
            return moonStyle(
                top:     palette.moon.top,
                bottom:  palette.moon.bottom,
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
    /// Shadow under the badge — a tight halo in the canvas colour so
    /// the pill lifts off the sky as one shape.
    var poiShadow: GraphicsContext.Filter {
        .shadow(color: .systemBackground,
                radius: 1, x: 0, y: 0)
    }

    // MARK: Text casing
    //
    // Apple Maps gives every label two distinct treatments, and the
    // distinction is the whole trick: a crisp *casing* (a tight
    // outline in a contrasting colour, doing the legibility work
    // against a busy background) AND a soft *drop shadow* (offset +
    // blurred, doing the depth/lift work). One shadow can't be both —
    // a radius big enough to read as a halo is too soft to read as an
    // outline. So we draw them separately: a real shadow filter for
    // lift, plus a faked stroke for the casing.
    //
    // SwiftUI's GraphicsContext can't stroke text, so the casing is
    // faked the classic way — draw the glyph several times in a ring
    // of small offsets (the border), then the fill on top.

    /// Soft drop shadow under label *text* — distinct from the
    /// badge's `poiShadow` halo. Subtle and a touch lowered so the
    /// text lifts without smearing; the casing does the legibility,
    /// this does the depth.
    var poiTextShadow: GraphicsContext.Filter {
        .shadow(color: .black.opacity(0.95),
                radius: 1.8, x: 0, y: 0.5)
    }

    /// Colour of the crisp casing around label text. `.primary` gives
    /// the punchy light-outline-on-colour look from the Apple Maps
    /// reference; switch to `.systemBackground` if you'd rather the
    /// casing recede into the sky than stand proud of it.
    var poiTextBorderColor: Color { .systemBackground }

    /// Casing half-width, in points. The glyph is redrawn in a ring
    /// this far out, so ~1pt reads as a clean hairline at footnote
    /// size; push toward 1.5 for a chunkier sticker edge.
    var poiTextBorderWidth: CGFloat { 2 }

    /// Eight offsets (NSEW + diagonals) forming the casing ring. Four
    /// would leave gaps at the corners; past eight costs draws for no
    /// visible gain at label sizes. Diagonals are scaled by cos 45° so
    /// every copy sits the same distance out — a circle, not a square.
    var poiTextBorderOffsets: [CGSize] {
        let d = poiTextBorderWidth
        let s = d * 0.70710678
        return [
            CGSize(width:  d, height:  0), CGSize(width: -d, height:  0),
            CGSize(width:  0, height:  d), CGSize(width:  0, height: -d),
            CGSize(width:  s, height:  s), CGSize(width:  s, height: -s),
            CGSize(width: -s, height:  s), CGSize(width: -s, height: -s)
        ]
    }

    /// Draws label text the Apple-Maps way: a soft drop shadow for
    /// depth, a crisp casing for legibility, then the visible `filled`
    /// shading on top.
    ///
    /// `cased` is the same string styled in the casing colour, passed
    /// in rather than derived so callers that build concatenated Text
    /// (e.g. the constellation ♥ prefix) keep control of styling. Both
    /// `filled` and `cased` should already carry the font.
    ///
    /// `ctx` is taken by value — drawing routes to the shared canvas,
    /// while transform / opacity / filters stay local to each copy, so
    /// the shadow filter never leaks onto the casing or fill.
    func drawCasedLabel(filled: Text,
                        cased:  Text,
                        at point: CGPoint,
                        anchor: UnitPoint,
                        in ctx: GraphicsContext) {
        // 1 — soft drop shadow, cast by the casing silhouette. This
        //     glyph is fully covered by passes 2–3; only its shadow
        //     escapes around the casing edge.
        var shadow = ctx
        shadow.addFilter(poiTextShadow)
        shadow.draw(cased, at: point, anchor: anchor)

        // 2 — crisp casing: the glyph redrawn in a ring around the
        //     anchor. Resolve once, redraw eight times.
        let resolved = ctx.resolve(cased)
        for off in poiTextBorderOffsets {
            ctx.draw(resolved,
                     at: CGPoint(x: point.x + off.width,
                                 y: point.y + off.height),
                     anchor: anchor)
        }

        // 3 — visible fill on top.
        ctx.draw(filled, at: point, anchor: anchor)
    }

    // MARK: Tier transitions
    //
    // Tiers used to pop in/out at a hard `renderedScale` threshold.
    // Instead each tier's opacity + scale ramps as a smooth function
    // of scale, centred on its old threshold, so a label eases in as
    // you pinch toward it and eases back out as you pinch away — the
    // transition tracks the gesture rather than snapping.

    /// Width of a tier's fade/scale ramp, as a fraction of its
    /// threshold. Narrow enough to feel responsive to a pinch, wide
    /// enough to read as an ease rather than a pop.
    var labelTierRampFraction: Double { 0.18 }

    /// Scale a tier grows through as it appears — from this floor up
    /// to 1. Subtle on purpose: the eye should read "settling in",
    /// not "zooming".
    var labelTierScaleFloor: CGFloat { 0.82 }

    /// Eased 0→1 appearance for a tier whose hard cut-off was
    /// `threshold`: 0 below the ramp, 1 above it, smoothstep across a
    /// band centred on `threshold`. A non-positive threshold means
    /// "always on" (the sun / moon badge) → fully present.
    func labelTierProgress(scale: Double, threshold: Double) -> Double {
        guard threshold > 0 else { return 1 }
        let band = labelTierRampFraction * threshold
        let t    = (scale - (threshold - band / 2)) / band
        let c    = min(max(t, 0), 1)
        return c * c * (3 - 2 * c)            // smoothstep
    }

    /// Map an eased tier progress to its scale factor.
    func labelTierScale(_ progress: Double) -> CGFloat {
        labelTierScaleFloor + (1 - labelTierScaleFloor) * CGFloat(progress)
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

        // Each tier eases in/out as a smooth function of scale rather
        // than popping at a hard threshold — see `labelTierProgress`.
        let badgeFade = labelTierProgress(scale: scale, threshold: style.badgeIn)
        let textFade  = labelTierProgress(scale: scale, threshold: style.textIn)

        // Tier 0 — maybe-dot, crossfading out as the badge fades in
        // across `badgeIn`. Shape + radius come from the category
        // style so a followed star collapses to a tiny pentagon.
        if drawDot && badgeFade < 1 {
            drawPOIDot(at: sc, style: style, opacity: 1 - badgeFade, in: &dc)
        }
        // Below the badge ramp entirely → the dot (if any) is all there is.
        guard badgeFade > 0 else { return }

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

        // Tier-1 context: fade + scale the badge (and its glyph)
        // around `sc` so it grows into place. The badge draws through
        // a scoped copy carrying the drop-shadow filter so the shadow
        // doesn't leak onto the glyph; both share this opacity + scale.
        var tier1 = dc.ctx
        tier1.opacity *= badgeFade
        let badgeScale = labelTierScale(badgeFade)
        tier1.translateBy(x: sc.x, y: sc.y)
        tier1.scaleBy(x: badgeScale, y: badgeScale)
        tier1.translateBy(x: -sc.x, y: -sc.y)

        // Apple-Maps-style soft drop shadow under the badge. Scoped
        // to a local context so the filter doesn't leak onto the
        // glyph drawn next (the text below gets its own shadowed
        // context so the pill reads as a single shape under one
        // shadow envelope).
        var shadowed = tier1
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
        tier1.draw(
            glyphText
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(style.symbolColor),
            at:     CGPoint(x: badgeRect.midX, y: badgeRect.midY),
            anchor: .center
        )

        // Tier 2 — text trailing to the right of the badge, fading +
        // scaling in around its leading anchor so it settles in from
        // the badge side rather than popping.
        //
        // The text picks up the same vertical gradient the badge uses
        // (lighter top, darker bottom), wrapped in an Apple-Maps-style
        // casing + drop shadow (see `drawCasedLabel`) so badge + text
        // read as a single legible pill against the sky.
        guard textFade > 0 else { return }
        let textGradient = LinearGradient(
            colors:     [style.gradientTop, style.gradientBottom],
            startPoint: .top,
            endPoint:   .bottom
        )
        let textAnchor = CGPoint(x: badgeRect.maxX + poiTextLeadingGap,
                                 y: sc.y)
        let textScale  = labelTierScale(textFade)
        var textCtx = dc.ctx
        textCtx.opacity *= textFade
        textCtx.translateBy(x: textAnchor.x, y: textAnchor.y)
        textCtx.scaleBy(x: textScale, y: textScale)
        textCtx.translateBy(x: -textAnchor.x, y: -textAnchor.y)

        let textFont = Font.footnote.weight(.bold)
        drawCasedLabel(
            filled: Text(text).font(textFont).foregroundStyle(textGradient),
            cased:  Text(text).font(textFont).foregroundStyle(poiTextBorderColor),
            at:     textAnchor,
            anchor: .leading,
            in:     textCtx
        )
    }

    /// Draws the tier-0 dot marker for a POI at `sc`, at `opacity`.
    /// Shape (circle / squircle) and radius come from the category
    /// style so a followed star collapses to a tiny pentagon rather
    /// than a plain dot. Pulled out of `drawPOILabel` so the dot can
    /// crossfade against the badge across the `badgeIn` threshold.
    private func drawPOIDot(
        at sc:    CGPoint,
        style:    POICategoryStyle,
        opacity:  Double,
        in dc:    inout EGraphicContext
    ) {
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
        var ctx = dc.ctx
        ctx.opacity *= opacity
        ctx.fill(path, with: .color(style.gradientBottom))
    }
}

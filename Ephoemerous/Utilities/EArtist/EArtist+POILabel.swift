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
// other rendering the layer drew at the same spot reads as
// "behind" the badge.

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
            // the early thresholds + favourite heart).
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
        .shadow(color: .black.opacity(0.5),
                radius: 4.8, x: 0, y: 2.5)
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

    // MARK: Selection promotion
    //
    // Tapping a POI promotes its label: the badge lifts off its precise
    // location, scales up, and the name slides to sit centred *under*
    // the dot in primary ink. Dead simple — a single `promotion` value
    // (0 = flat label, 1 = fully promoted) eased 0→1 over a quick
    // scale-up. No wiggle, no overlay, no cache: the brief ease is the
    // only thing that wakes the canvas, and it parks again right after.
    // The caller derives `promotion` from "seconds since selection"
    // via `poiSelectProgress`.

    /// Enlarged scale a fully-promoted badge settles at.
    var poiSelectScale: CGFloat { 1.45 }
    /// How far the promoted badge lifts above the dot, as a multiple
    /// of `badgeSize`.
    var poiSelectLiftFactor: CGFloat { 1.45 }
    /// Gap between the dot and the top of the dropped-below name.
    var poiSelectNameDrop: CGFloat { 7 }
    /// Radius of the precise-location dot left under a promoted pin.
    var poiSelectDotRadius: CGFloat { 2.5 }
    /// Seconds the promotion takes to ease in / out — a quick scale-up.
    var poiSelectRise: Double { 0.3 }
    /// Seconds after a (de)selection past which the promotion is settled.
    /// It's a plain ease now (no wiggle tail), so this is just the rise:
    /// `EAppState` keeps the canvas ticking for exactly the ease, then
    /// parks — no long redraw window, no stutter.
    var poiSelectSettleDuration: Double { poiSelectRise }

    /// Eased promotion value, lerped `from → to` (0 unselected, 1
    /// selected) over `poiSelectRise` seconds via smoothstep.
    /// `elapsed` is seconds since the selection toggled.
    func poiSelectProgress(from: Double, to: Double, elapsed: Double) -> Double {
        let t = min(max(elapsed / poiSelectRise, 0), 1)
        let e = t * t * (3 - 2 * t)
        return from + (to - from) * e
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
    /// - `promotion`: 0 = flat label (default — every existing caller
    ///   renders exactly as before), 1 = fully promoted "selected"
    ///   pin (lifted off the dot, scaled up, name centred below in
    ///   primary). The caller derives this from time-since-selection.
    func drawPOILabel(
        at sc: CGPoint,
        glyph: POIGlyph,
        text: String,
        category: POICategory,
        drawDot: Bool = false,
        promotion: Double = 0,
        in dc: inout EGraphicContext
    ) {
        let style = poiStyle(for: category)
        let scale = dc.renderedScale
        let promo = min(max(promotion, 0), 1)

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
        //
        // Selection promotion lifts the badge off its dot, scales it
        // up (× the transient `wiggle` spring) and grows a downward
        // tail back to the precise location — every term scaled by
        // `promo`, so `promo == 0` reproduces the flat label exactly.
        let lift        = CGFloat(promo) * poiSelectLiftFactor * style.badgeSize
        let badgeCenter = CGPoint(x: sc.x, y: sc.y - lift)

        // Effective badge scale: tier fade-in × selection enlargement.
        // At promo 0 this collapses to just the tier scale, leaving
        // unselected labels untouched.
        let tierScale  = labelTierScale(badgeFade)
        let selScale   = 1 + CGFloat(promo) * (poiSelectScale - 1)
        let badgeScale = tierScale * selScale

        // Scale baked into GEOMETRY, not the drawing context. A scaled
        // badge rect + matching scaled bulge reproduce the enlarged
        // badge exactly — but because the casing stroke + drop shadow
        // are then applied in unscaled screen space, the border width
        // and shadow blur/offset stay fixed (matching the text) instead
        // of ballooning with the badge.
        let scaledHalf  = style.badgeSize / 2 * badgeScale
        let scaledBulge = poiBadgeBulge * badgeScale
        let badgeRect = CGRect(x: badgeCenter.x - scaledHalf,
                               y: badgeCenter.y - scaledHalf,
                               width:  scaledHalf * 2,
                               height: scaledHalf * 2)
        let badgePath = Squircle(corners: style.badgeCorners,
                                 bulge:   scaledBulge)
            .path(in: badgeRect)

        // Downward tail from the badge toward the precise dot — a
        // triangle whose base width grows with promo (degenerate /
        // invisible at promo 0). Drawn in screen space, NOT through the
        // badge's scale transform. Its tip stops `poiSelectTailGap`
        // short of `sc` so the dot stays a distinct mark the arrow
        // points at rather than one the tail disappears under. Filled
        // in `.systemBackground` to match the badge border + casing.
//        if promo > 0 {
//            let halfH    = style.badgeSize / 2 * badgeScale
//            let tailTopY = badgeCenter.y + halfH - 1   // slight overlap into the badge
//            let tailTipY = sc.y - poiSelectTailGap     // stop short of the dot
//            let baseHalf = CGFloat(promo) * style.badgeSize * 0.30
//            var tail = Path()
//            tail.move   (to: CGPoint(x: sc.x - baseHalf, y: tailTopY))
//            tail.addLine(to: CGPoint(x: sc.x + baseHalf, y: tailTopY))
//            tail.addLine(to: CGPoint(x: sc.x,            y: tailTipY))
//            tail.closeSubpath()
//            var tailCtx = dc.ctx
//            tailCtx.opacity *= badgeFade
//            tailCtx.addFilter(poiTextShadow)
//            tailCtx.fill(tail, with: .color(.systemBackground))
//        }

        // Badge casing — exactly the layering `drawCasedLabel` uses for
        // text, so badge and text wear identical shadows: the casing is
        // an OUTSET squircle (the border colour, `poiTextBorderWidth`
        // wider all round, same as the text ring). Draw it three times:
        //
        //   1 — shadow: the casing silhouette, shadowed
        //   2 — casing: the same silhouette, unshadowed, ON TOP — this
        //       covers the shadow's interior so only a thin soft rim
        //       escapes beyond the badge (the text's white casing hides
        //       its shadow the same way; without this the badge wore the
        //       full halo and read heavier than the text)
        //   3 — fill: the gradient badge face, inset by the border
        //
        // All in UNSCALED screen space — the scale is already baked into
        // the geometry — so the shadow + border stay text-sized instead
        // of ballooning with the badge.
        let casingRect = badgeRect.insetBy(dx: -poiTextBorderWidth/2,
                                           dy: -poiTextBorderWidth/2)
        let casingPath = Squircle(corners: style.badgeCorners,
                                  bulge:   scaledBulge)
            .path(in: casingRect)

        // The shadow is cast by the casing OUTLINE (a thin stroke), not
        // the solid squircle — a filled shape throws a big dense blob,
        // while the text's shadow is wispy because letterforms are thin
        // line-art. Stroking the outline at the border width makes the
        // badge cast the same thin, soft halo the text does. The solid
        // casing fill in pass 2 then covers the inner half, leaving only
        // the soft outer rim — exactly like the text casing.
        var shadow = dc.ctx
        shadow.opacity *= badgeFade
        shadow.addFilter(poiTextShadow)
        shadow.stroke(casingPath,
                      with: .color(poiTextBorderColor),
                      lineWidth: poiTextBorderWidth)

        var caseCtx = dc.ctx
        caseCtx.opacity *= badgeFade
//        caseCtx.fill(casingPath, with: .color(poiTextBorderColor))

        let gradient = Gradient(colors: [style.gradientTop, style.gradientBottom])
        var fillCtx = dc.ctx
        fillCtx.opacity *= badgeFade
        fillCtx.fill(
            badgePath,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: badgeRect.midX, y: badgeRect.minY),
                endPoint:   CGPoint(x: badgeRect.midX, y: badgeRect.maxY)
            )
        )

        // Glyph inside the badge — drawn through a scaled context so it
        // grows with the badge (it carries no shadow/border, so scaling
        // the context here is harmless). Wrapping `Image(systemName:)`
        // in `Text` routes both branches through the same
        // `ctx.draw(Text, at:, anchor:)` overload (Image alone doesn't
        // accept `.font` / `.foregroundStyle`).
        var glyphCtx = dc.ctx
        glyphCtx.opacity *= badgeFade
        glyphCtx.translateBy(x: badgeCenter.x, y: badgeCenter.y)
        glyphCtx.scaleBy(x: badgeScale, y: badgeScale)
        glyphCtx.translateBy(x: -badgeCenter.x, y: -badgeCenter.y)

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
        glyphCtx.draw(
            glyphText
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(style.symbolColor),
            at:     badgeCenter,
            anchor: .center
        )

        // Precise-location dot left under a promoted pin — the tail
        // points at it, and it marks the exact spot the badge lifted
        // off. Fades in with promo; absent on a flat label.
        if promo > 0 {
            let r = poiSelectDotRadius
            let dotRect = CGRect(x: sc.x - r, y: sc.y - r, width: 2 * r, height: 2 * r)
            var dotCtx = dc.ctx
            dotCtx.opacity *= promo * badgeFade
            dotCtx.addFilter(poiTextShadow)
            dotCtx.fill(Path(ellipseIn: dotRect), with: .color(style.gradientBottom))
        }

        // Tier 2 — the name. Trailing-right of the badge when flat; as
        // the label promotes it slides to sit centred *below* the
        // precise dot and recolours from the badge gradient to primary
        // ink (the Apple-Maps selected-label treatment). Selection
        // forces the name visible even if the zoom tier hasn't revealed
        // text yet, so a tapped badge always shows its name.
        let textOpacity = max(textFade, promo)
        guard textOpacity > 0 else { return }

        let textFont = Font.footnote.weight(.bold)
        let textGradient = LinearGradient(
            colors:     [style.gradientTop, style.gradientBottom],
            startPoint: .top,
            endPoint:   .bottom
        )

        // Flat (trailing, vertically-centred) vs promoted (centred
        // below the dot) anchor + point — lerped by promo. The flat
        // endpoint is computed from `sc` (not the lifted badge) so it
        // matches the unselected layout exactly at promo 0.
        let flatPoint = CGPoint(x: sc.x + style.badgeSize / 2 + poiTextLeadingGap,
                                y: sc.y)
        let selPoint  = CGPoint(x: sc.x, y: sc.y + poiSelectNameDrop)
        let textPoint = CGPoint(
            x: flatPoint.x + (selPoint.x - flatPoint.x) * CGFloat(promo),
            y: flatPoint.y + (selPoint.y - flatPoint.y) * CGFloat(promo)
        )
        // Leading (0, 0.5) → top-centre (0.5, 0) as it promotes.
        let textAnchor = UnitPoint(x: CGFloat(promo) * 0.5,
                                   y: 0.5 - CGFloat(promo) * 0.5)

        let textScale = labelTierScale(textFade)
        var textCtx = dc.ctx
        textCtx.opacity *= textOpacity
        textCtx.translateBy(x: textPoint.x, y: textPoint.y)
        textCtx.scaleBy(x: textScale, y: textScale)
        textCtx.translateBy(x: -textPoint.x, y: -textPoint.y)

        // Crossfade the fill: gradient when flat, primary when
        // promoted. Drawing both through the casing at complementary
        // opacities keeps it a clean morph — only the selected label is
        // ever mid-crossfade, so the doubled draw is negligible.
        if promo < 1 {
            var flatCtx = textCtx
            flatCtx.opacity *= (1 - promo)
            drawCasedLabel(
                filled: Text(text).font(textFont).foregroundStyle(textGradient),
                cased:  Text(text).font(textFont).foregroundStyle(poiTextBorderColor),
                at:     textPoint,
                anchor: textAnchor,
                in:     flatCtx
            )
        }
        if promo > 0 {
            var selCtx = textCtx
            selCtx.opacity *= promo
            drawCasedLabel(
                filled: Text(text).font(textFont).foregroundStyle(Color.primary),
                cased:  Text(text).font(textFont).foregroundStyle(poiTextBorderColor),
                at:     textPoint,
                anchor: textAnchor,
                in:     selCtx
            )
        }
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

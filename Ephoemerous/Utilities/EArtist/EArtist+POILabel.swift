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
//
// Supporting pieces live in sibling files:
//   • POITypes.swift            — POIGlyph / POICategory / myth enums
//   • EArtist+POIStyle.swift     — poiStyle(for:) + badge tuning
//   • EArtist+POIText.swift      — drawCasedLabel + casing tuning
//   • EArtist+POITiers.swift     — labelTierProgress / labelTierScale
//   • EArtist+POISelection.swift — poiSelectProgress + promotion tuning
extension EArtist {

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

        // Resolve the badge's asset gradient colours to concrete RGBA once
        // (used by the badge fill, the dot, and the text gradient) so this
        // badge does no main-thread asset I/O per draw.
        let gradTop    = dc.resolve(style.gradientTop)
        let gradBottom = dc.resolve(style.gradientBottom)

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

        let gradient = Gradient(colors: [gradTop, gradBottom])
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
            dotCtx.fill(Path(ellipseIn: dotRect), with: .color(gradBottom))
        }

        // Tier 2 — the name. Trailing-right of the badge when flat; as
        // the label promotes it slides to sit centred *below* the
        // precise dot and recolours from the badge gradient to primary
        // ink (the Apple-Maps selected-label treatment). Selection
        // forces the name visible even if the zoom tier hasn't revealed
        // text yet, so a tapped badge always shows its name.
        let textOpacity = max(textFade, promo)
        guard textOpacity > 0 else { return }

        // Sky-object name → serif. Set explicitly (not inherited from a
        // global fontDesign) so the canvas label stays serif while the
        // rest of the app renders standard.
        let textFont = Font.system(.footnote, design: .serif).weight(.bold)
        let textGradient = LinearGradient(
            colors:     [gradTop, gradBottom],
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

        // Tier reveal scale × continuous zoom response, so the label keeps
        // breathing with the map after it's revealed (not locked to one
        // size). Anchored at 1.0 for the default view — see `poiTextZoomFactor`.
        let textScale = labelTierScale(textFade) * poiTextZoomFactor(forScale: scale)
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
        ctx.fill(path, with: .color(dc.resolve(style.gradientBottom)))
    }
}

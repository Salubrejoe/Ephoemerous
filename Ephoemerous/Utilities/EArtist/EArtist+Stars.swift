import SwiftUI
import LoreKit

// MARK: - Stars
// Every star is a small filled 5-point squircle with a fixed bulge,
// rendered from one cached unit-rect path. A deterministic per-star
// spin (RA / Dec derived) keeps neighbouring stars from sharing
// rotations — one shape, all stars.
extension EArtist {

    var starZoomExp : Double { 0.01 }   // sub-linear: r ∝ scale^starZoomExp

    private static let starCorners: Int    = 5
    private static let starBulge:   CGFloat = 6

    /// Single cached unit-rect (−1…1) star path. Built once at
    /// type-load; per-frame work is just translate + rotate + scale
    /// + fill against this one shape.
    private static let starPath: Path = Squircle(
        corners: starCorners,
        bulge:   starBulge
    )
    .path(in: CGRect(x: -1, y: -1, width: 2, height: 2))

    func starPointFallsWithinMarigin(_ screenPoint: CGPoint,
                                     in dc: EGraphicContext,
                                     margin: Double = 20) -> Bool {
        screenPoint.x > -margin &&
        screenPoint.x < dc.size.width  + margin &&
        screenPoint.y > -margin &&
        screenPoint.y < dc.size.height + margin
    }

    /// Magnitude-clamped on-screen radius for a star, in points (no
    /// zoom factor applied — the caller folds in `renderedScale` for
    /// the actual draw).
    func starRadius(_ star: EStar, in dc: EGraphicContext) -> Double {
        // Brightness drops by ~2.512× per magnitude step; we follow
        // the same shape but with a tunable ratio so the contrast on
        // screen is much steeper than a linear mapping would give.
        let raw     = AstroConstants.dotBaseRadius
                    * pow(AstroConstants.dotMagRatio, star.magnitude)
        return min(AstroConstants.dotMaxRadius,
                   max(AstroConstants.dotMinRadius, raw))
    }

    func drawStar(_ star: EStar, at sc: CGPoint, in dc: inout EGraphicContext) {
        let baseR = starRadius(star, in: dc)
        let r     = baseR * pow(dc.renderedScale, starZoomExp)
        // Sub-pixel stars are invisible on Retina anyway — skipping
        // them spares a `translate + rotate + scale + fill` that would
        // paint nothing readable.
        guard r >= 0.1 else { return }
        let spin = starSpin(of: star)

        var local = dc.ctx
        local.translateBy(x: sc.x, y: sc.y)
        local.rotate(by: spin)
        local.scaleBy(x: r, y: r)
//        local.addFilter(.brightness(0.7))
        local.addFilter(.shadow(color: star.spectralClass.color, radius: 1))
        local.fill(
            Self.starPath,
            with: .color(.primary)
//            with: .color(star.spectralClass.lightColor.opacity(0.2))
        )
    }

    // MARK: - Over-zoom name labels
    // Past the max scale (and faintly hinting just before it), every
    // generic star shows its catalogue designation — plain cased text, the
    // same casing as the POI labels, fading in with the zoom overshoot and
    // out as the view settles back. No badge, no selection.

    /// Scale at which the over-zoom labels begin to show and the scale by
    /// which they're fully in (well into the rubber overshoot). Anchored
    /// to `AstroConstants.maximumScale` — and starting strictly AT the
    /// ceiling, not before: below it `overZoomLabelOpacity` is exactly 0,
    /// so ordinary max-zoom panning never pays a single label draw; only
    /// pushing into the rubber buys them in.
    var overZoomLabelStartScale: Double  { AstroConstants.maximumScale }
    var overZoomLabelFullScale:  Double  { AstroConstants.maximumScale * 1.30 }
    /// Gap from the star dot to the leading edge of its name.
    var overZoomLabelGap:        CGFloat { 7 }

    /// 0…1 reveal for the over-zoom star-name labels, smoothstepped between
    /// `overZoomLabelStartScale` and `overZoomLabelFullScale`. 0 at normal
    /// zoom (no label work), so callers can early-out.
    func overZoomLabelOpacity(scale: Double) -> Double {
        let lo = overZoomLabelStartScale
        let hi = overZoomLabelFullScale
        guard hi > lo else { return scale >= hi ? 1 : 0 }
        let t = (scale - lo) / (hi - lo)
        let c = min(max(t, 0), 1)
        return c * c * (3 - 2 * c)        // smoothstep
    }

    /// Plain catalogue-designation label for a star, trailing-right of its
    /// dot — used only during over-zoom. ONE quiet secondary-colour pass,
    /// deliberately NOT the cased POI treatment: that's a shadow (blur
    /// filter) + 8 casing redraws + fill per label, and these labels run
    /// on EVERY visible star — the cased version multiplied into
    /// thousands of text draws + hundreds of blurs per over-zoom frame.
    /// `opacity` is the `overZoomLabelOpacity`, so it transitions in/out
    /// with the zoom.
    func drawStarNameLabel(_ star: EStar, at sc: CGPoint,
                           opacity: Double, in dc: inout EGraphicContext) {
        guard opacity > 0.01 else { return }
        // Bayer designations only — "α CMa" yes, "23 UMa" / "HR" no. The
        // Greek-letter stars are the figure-bearers worth a whisper; it
        // also keeps the over-zoom label count to a fraction of the
        // field. One scalar test: Α…ω is U+0391…U+03C9.
        guard let first = star.name.unicodeScalars.first,
              (0x0391...0x03C9).contains(first.value) else { return }
        let point = CGPoint(x: sc.x + overZoomLabelGap, y: sc.y)
        var ctx = dc.ctx
        ctx.opacity *= opacity
        ctx.draw(
            Text(star.displayName)
                .font(.system(.caption2).weight(.semibold))
                .fontDesign(.serif)            // sky-object name → serif
                .foregroundStyle(.secondary),
            at:     point,
            anchor: .leading                   // text extends right from the dot
        )
    }

    /// Deterministic-but-arbitrary rotation derived from the star's
    /// RA / Dec — every star keeps a fixed orientation across frames
    /// while no two neighbours line up.
    private func starSpin(of star: EStar) -> Angle {
        let raw = star.rightAscension.radians * 73
                + star.declination.radians   * 137
        return .radians(raw.truncatingRemainder(dividingBy: 2 * .pi))
    }
}

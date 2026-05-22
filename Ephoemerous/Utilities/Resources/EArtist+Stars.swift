import SwiftUI

// MARK: - Stars
// Every star is a small filled 5-point squircle whose `bulge` is
// snapped to one of a handful of cached unit-rect paths
// (`starBulgePaths`). At render time we just pick the bucket the
// star's current twinkle phase lands in — no `Path` allocations in
// the hot loop. A deterministic per-star spin (derived from RA / Dec)
// keeps neighbouring stars from sharing rotations.
extension EArtist {

    var starZoomExp : Double { 0.01 }   // sub-linear: r ∝ scale^starZoomExp

    private static let starCorners: Int = 5

    // Cached unit-rect (−1…1) star paths, one per bulge bucket. Built
    // once at type-load; never re-allocated.
    private static let starBulgePaths: [Path] = {
        let n  = AstroConstants.twinkleBulgeBuckets
        let lo = AstroConstants.twinkleBulgeMin
        let hi = AstroConstants.twinkleBulgeMax
        return (0..<n).map { i in
            let t = Double(i) / Double(max(n - 1, 1))
            let b = lo + (hi - lo) * t
            return Squircle(corners: starCorners, bulge: CGFloat(b))
                .path(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        }
    }()

    func starPointFallsWithinMarigin(_ screenPoint: CGPoint,
                                     in dc: EGraphicContext,
                                     margin: Double = 20) -> Bool {
        screenPoint.x > -margin &&
        screenPoint.x < dc.size.width  + margin &&
        screenPoint.y > -margin &&
        screenPoint.y < dc.size.height + margin
    }

    /// Magnitude-clamped on-screen radius for a star, modulated by the
    /// per-star twinkle when `twinkling` is true. Pass `false` from
    /// callers that drive their own slow animation (e.g. the selected-
    /// star halo's breath) so twinkle and breath don't compound into
    /// shimmer.
    func starRadius(_ star: EStar, in dc: EGraphicContext, twinkling: Bool = true) -> Double {
        // Brightness drops by ~2.512× per magnitude step; we follow
        // the same shape but with a tunable ratio so the contrast on
        // screen is much steeper than a linear mapping would give.
        let raw     = AstroConstants.dotBaseRadius
                    * pow(AstroConstants.dotMagRatio, star.magnitude)
        let clamped = min(AstroConstants.dotMaxRadius,
                          max(AstroConstants.dotMinRadius, raw))

        guard twinkling else { return clamped }

        // Phase is deterministic on RA / Dec — the 17.3 / 7.9 multipliers
        // are big enough to decorrelate even neighbouring stars. The
        // previous `.random(in: -1...1)` here was a bug + a hot spot:
        // a per-frame RNG call per star (60k+/s) that also jittered the
        // sine, so the twinkle never read as a smooth pulse.
        let ra      = star.rightAscension.radians
        let dec     = star.declination.radians
        let phase   = ra  * AstroConstants.twinklePhaseRA
                    + dec * AstroConstants.twinklePhaseDec
        let twinkle = 1.0
                    + AstroConstants.twinkleAmplitude
                    * sin(dc.state.animationTime * AstroConstants.twinkleFrequency + phase)

        
        let isSelected = dc.state.selectedStars.contains(star)
        let returedTwinkle = isSelected ? twinkle : 1.0
        
        return clamped * returedTwinkle
    }

    func drawStar(_ star: EStar, at sc: CGPoint, in dc: inout EGraphicContext) {
        let baseR = starRadius(star, in: dc)
        let r     = baseR * pow(dc.state.renderedScale, starZoomExp)
        // Sub-pixel stars are invisible on Retina anyway — skipping
        // them spares a `translate + rotate + scale + fill` that would
        // paint nothing readable.
        guard r >= 0.3 else { return }
        let spin  = starSpin(of: star)
        let bulge = bulgeBucket(for: star, in: dc)

        var local = dc.ctx
        local.translateBy(x: sc.x, y: sc.y)
        local.rotate(by: spin)
        local.scaleBy(x: r, y: r)
        local.fill(
            Self.starBulgePaths[bulge],
            with: .color(
                dc.state.selectedStars.contains(star) ? star.spectralClass.color.opacity(0.9) : .tertiary
            )
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

    /// Pick a cached path whose bulge matches the current shape phase.
    /// Per-star RA / Dec offset desyncs neighbours; no random jitter
    /// and a slow dedicated frequency make the shape ease between
    /// buckets rather than flicker. Sin naturally lingers near the
    /// extremes, so wide bulge ranges read as a slow "breathe in /
    /// breathe out".
    private func bulgeBucket(for star: EStar, in dc: EGraphicContext) -> Int {
        let ra    = star.rightAscension.radians
        let dec   = star.declination.radians
        let phase = ra  * AstroConstants.twinklePhaseRA
                  + dec * AstroConstants.twinklePhaseDec
        let s     = sin(dc.state.animationTime * AstroConstants.twinkleBulgeFrequency + phase)
        let t     = (s + 1) / 2     // 0…1
        let n     = AstroConstants.twinkleBulgeBuckets
        return max(0, min(n - 1, Int((t * Double(n - 1)).rounded())))
    }
}

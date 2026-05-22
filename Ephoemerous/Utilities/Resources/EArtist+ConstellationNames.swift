import SwiftUI

// MARK: - Constellation names
// Quiet labels anchored at each constellation's figure-star centroid.
// Style mirrors the screenshot reference: small, light-weight, all-caps,
// faded — they read as a typographic background, not as content.
//
// Reveal behaviour: the labels appear at `labelMinScale` (very small,
// almost a serif italic whisper) and grow modestly as the user zooms
// further in. The same growth curve and font family are reused by
// selected-star labels via `scaledLabelSize` / `serifLabelFont` so the
// two label classes share a coherent typographic voice.
extension EArtist {

    // MARK: Reveal + sizing
    var labelMinScale            : Double  { 80 }   // hide the label below this
    var labelTapMinScale         : Double  { 130 }  // suppress the tap target below this
    var labelBaseSize            : CGFloat { 5 }    // pt at threshold
    var labelGrowthRate          : CGFloat { 0.03 } // pt added per unit of scale past threshold
    var labelMaxSize             : CGFloat { 11 }   // cap so labels never bloat

    // MARK: Constellation label style
    var constellationLabelColor     : Color  { .secondary }
    var constellationLabelOpacity   : Double { 0.55 }
    var constellationLabelTracking  : Double { 1.5 }

    // MARK: Tap-target capsule
    // The hit capsule hugs the *rendered word* — width from the measured
    // text, height just the line box — so a tiny low-scale label gets a
    // tiny target. A fixed 44pt circle is what blanketed the pole and
    // made pinch-to-zoom impossible; these padding values stay small on
    // purpose so neighbouring labels keep clear gaps between them.
    var constellationHitPadH        : CGFloat { 10 }   // L+R padding around the word
    var constellationHitPadV        : CGFloat { 12 }   // T+B padding — label is short, this is the grabbable strip

    // MARK: Horizon visibility
    // Constellations whose centroid never climbs above the horizon for
    // the observer are dropped entirely — no label, no tap target. The
    // margin keeps ones that only *partly* dip below: we test the
    // centroid, and a constellation spans tens of degrees of sky.
    var constellationVisibilityMargin : Double { 25 }

    /// `true` when any part of a constellation near `decDegrees` rises
    /// above the horizon for an observer at `observerLatitude`. A point
    /// at declination δ culminates at altitude 90° − |φ − δ|, so it is
    /// below the horizon for the whole sidereal day once |φ − δ| ≥ 90°.
    func constellationEverVisible(decDegrees: Double, observerLatitude: Double) -> Bool {
        abs(observerLatitude - decDegrees) < 90 + constellationVisibilityMargin
    }

    /// Scale-driven font size, or `nil` when the label should be hidden
    /// because we're below `labelMinScale`. Callers can use the `nil`
    /// case to short-circuit projection + layout work.
    func scaledLabelSize(for renderedScale: Double) -> CGFloat? {
        guard renderedScale >= labelMinScale else { return nil }
        let raw = labelBaseSize + CGFloat(renderedScale - labelMinScale) * labelGrowthRate
        return min(labelMaxSize, raw)
    }

    /// Shared serif italic family — used for both constellation names
    /// and selected-star labels so the two never disagree on voice.
    func serifLabelFont(size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .serif).italic()
    }

    /// Returns the all-caps form Stellarium-style labels use (e.g.
    /// "CASSIOPEIA"). Falls back to the IAU abbrev if no full name.
    func constellationLabelText(for cons: EConstellation) -> String {
        cons.fullName.uppercased()
    }

    func drawConstellationLabel(_ cons: EConstellation, at sc: CGPoint,
                                size: CGFloat, in dc: inout EGraphicContext) {
        let text = Text(constellationLabelText(for: cons))
            .font(serifLabelFont(size: size))
            .tracking(constellationLabelTracking)
            .foregroundStyle(constellationLabelColor.opacity(constellationLabelOpacity))
        dc.ctx.draw(text, at: sc, anchor: .center)
    }
}

import SwiftUI

// MARK: - Selected stars
// Two visual treatments, both routed through `drawSelectedStar`:
//   • User-selected stars get a breathing halo (a 5-point squircle
//     that scales + spins slowly) drawn behind the regular star body.
//   • Constellation members keep a plain identity ring — breathing a
//     whole dense constellation would shimmer.
//
// `selectedHaloUnitPath` is cached once at type-load; per-frame work
// is just translate + scale + rotate + stroke.
extension EArtist {

    // MARK: Ring (constellation members)
    var constellationStarRingRadius : CGFloat { 2.0 }
    var constellationStarRingWidth  : CGFloat { 0.75 }
    var starLabelOffset             : CGPoint { CGPoint(x: 12, y: -4) }
    var starLabelOpacity            : Double  { 0.9 }

    // MARK: Halo (selected stars)
    var selectedHaloMinScale : CGFloat { 0.5 }   // × star radius at breath trough — hidden behind body
    var selectedHaloMaxScale : CGFloat { 2.5 }   // × star radius at breath peak  — visible past body
    var selectedHaloPeriod   : Double  { 5.0 }   // seconds per breath cycle
    var selectedHaloSpinRate : Double  { 0.2 }   // rad/s — gentle rotation
    var selectedHaloOpacity  : Double  { 0.6 }

    private static let selectedHaloUnitPath: Path = Squircle(corners: 5, bulge: 12)
        .path(in: CGRect(x: -1, y: -1, width: 2, height: 2))

    /// Breathing halo for selected stars — a 5-point squircle that
    /// scales between `selectedHaloMinScale` and `selectedHaloMaxScale`
    /// (relative to the star's own display radius) on a cosine breath,
    /// rotating slowly at `selectedHaloSpinRate`. Caller redraws the
    /// star body on top so the halo reads as "behind" it.
    func drawBreathingHalo(
        at sc: CGPoint,
        starRadius: CGFloat,
        color: Color,
        time t: Double,
        in dc: inout EGraphicContext
    ) {
        let phase = 0.5 - 0.5 * cos(2 * .pi * t / selectedHaloPeriod)    // 0 → 1 → 0
        let r     = starRadius * (selectedHaloMinScale + (selectedHaloMaxScale - selectedHaloMinScale) * phase)
        let spin  = Angle.radians(t * selectedHaloSpinRate)

        var local = dc.ctx
        local.translateBy(x: sc.x, y: sc.y)
        local.rotate(by: spin)
        local.scaleBy(x: r, y: r)
        local.stroke(Self.selectedHaloUnitPath,
                     with: .color(color),
                     lineWidth: 0.2)
    }

    func drawSelectedStar(_ star: EStar, at sc: CGPoint,
                          isSelected: Bool, isCurrentlyDisplayed: Bool,
                          showLabel: Bool, in dc: inout EGraphicContext) {
        if isSelected {
            // Halo size opts out of twinkle so the slow breath isn't
            // also pulsing at the star's twinkle frequency — twinkle
            // belongs to the star body underneath, breath belongs to
            // the halo.
            let starR = CGFloat(starRadius(star, in: dc, twinkling: false)) * 0.5
                      * CGFloat(pow(dc.renderedScale, starZoomExp))
            drawBreathingHalo(at:         sc,
                              starRadius: starR,
//                              color:      .primary,
                              color:    star.spectralClass.color,
                              time:       dc.animationTime,
                              in:         &dc)
            // Re-paint the star body so the halo reads as "behind" it.
            drawStar(star, at: sc, in: &dc)
        } else {
            let r    = constellationStarRingRadius
            let ring = Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r,
                                              width: r * 2, height: r * 2))
            dc.ctx.stroke(ring,
                          with: .color(.primary),
                          lineWidth: constellationStarRingWidth)
        }

        // Star labels share the constellation labels' reveal curve —
        // hidden below `labelMinScale`, growing gently with zoom — and
        // borrow their serif italic family so the two label classes
        // read as one typographic voice. The currently-displayed star
        // gets a heavier weight as the only hierarchy distinction.
        if let size = scaledLabelSize(for: dc.renderedScale) {
            let weight: Font.Weight = isCurrentlyDisplayed ? .heavy : .light
            dc.ctx.draw(
                Text(star.displayName)
                    .font(serifLabelFont(size: size, weight: weight))
                    .foregroundStyle(.primary),
                at:     CGPoint(x: sc.x + starLabelOffset.x,
                                y: sc.y + starLabelOffset.y),
                anchor: .leading
            )
        }
    }
}

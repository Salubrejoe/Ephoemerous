import SwiftUI
import LoreKit

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

    // The Apple-Maps-style "followed star" badge is drawn by
    // `drawPOILabel(.followedStar, …)` in `SelectedStarsLayer`. The
    // breathing halo above continues to live in front of it as the
    // "this one is followed" signal.
}

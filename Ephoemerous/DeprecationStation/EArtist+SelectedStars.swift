import SwiftUI
import LoreKit

// MARK: - Selected stars
// Followed-star visual furniture. The badge + text live in
// `drawPOILabel(.followedStar, …)`; this file owns the slow
// breathing halo that sits *behind* the badge as the "this one is
// followed" signal.
//
// `selectedHaloUnitPath` is cached once at type-load; per-frame
// work is just translate + scale + rotate + stroke.
extension EArtist {

    var selectedHaloMinScale : CGFloat { 1.5 }   // × star radius at breath trough — hidden behind body
    var selectedHaloMaxScale : CGFloat { 2.5 }   // × star radius at breath peak  — visible past body
    var selectedHaloPeriod   : Double  { 5.0 }   // seconds per breath cycle
    var selectedHaloSpinRate : Double  { 0.2 }   // rad/s — gentle rotation

    private static let selectedHaloUnitPath: Path = Squircle(corners: 5, bulge: 12)
        .path(in: CGRect(x: -1, y: -1, width: 2, height: 2))

    /// Breathing halo for selected stars — a 5-point squircle that
    /// scales between `selectedHaloMinScale` and `selectedHaloMaxScale`
    /// (relative to the star's own display radius) on a cosine breath,
    /// rotating slowly at `selectedHaloSpinRate`.
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
}

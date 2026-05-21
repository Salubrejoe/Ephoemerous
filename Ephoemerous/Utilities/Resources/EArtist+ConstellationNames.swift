import SwiftUI

// MARK: - Constellation names
// Quiet labels anchored at each constellation's figure-star centroid.
// Style mirrors the screenshot reference: small, light-weight, all-caps,
// faded — they read as a typographic background, not as content.
extension EArtist {

    var constellationLabelFont      : Font   { .system(size: 9, weight: .light, design: .serif).italic() }
    var constellationLabelColor     : Color  { .secondary }
    var constellationLabelOpacity   : Double { 0.55 }
    var constellationLabelTracking  : Double { 1.5 }

    /// Returns the all-caps form Stellarium-style labels use (e.g.
    /// "CASSIOPEIA"). Falls back to the IAU abbrev if no full name.
    func constellationLabelText(for cons: EConstellation) -> String {
        cons.fullName.uppercased()
    }

    func drawConstellationLabel(_ cons: EConstellation, at sc: CGPoint, in dc: inout EGraphicContext) {
        let text = Text(constellationLabelText(for: cons))
            .font(constellationLabelFont)
            .tracking(constellationLabelTracking)
            .foregroundStyle(constellationLabelColor.opacity(constellationLabelOpacity))
        dc.ctx.draw(text, at: sc, anchor: .center)
    }
}

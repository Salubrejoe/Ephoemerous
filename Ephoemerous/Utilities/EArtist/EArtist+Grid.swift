import SwiftUI

// MARK: - Grid
// Coordinate grid drawn by `EarthGridLayer` — meridians, parallels,
// pole + RA labels. Thin, desaturated tint so the grid sits behind
// the bright content (sun, moon, planets, stars) without competing.
extension EArtist {

    var gridColor : Color  { .tertiary.opacity(0.2) }
    var gridWidth : Double { 0.55 }

    /// Tiny on-canvas text drawn in the grid's voice — used by the
    /// pole-pole labels ("N" / "S") and the RA hour numerals
    /// ("0h" / "6h" / "12h" / "18h"). Centred on `sc` and tinted
    /// `gridColor`; `weight` lets callers thicken specific labels
    /// (the poles are semibold, the hours are regular).
    func drawGridLabel(_ text: String,
                       at sc: CGPoint,
                       weight: Font.Weight = .regular,
                       in dc: inout EGraphicContext) {
        dc.ctx.draw(
            Text(text)
                .font(.footnote.weight(weight))
                .foregroundStyle(gridColor),
            at:     sc,
            anchor: .center
        )
    }
}

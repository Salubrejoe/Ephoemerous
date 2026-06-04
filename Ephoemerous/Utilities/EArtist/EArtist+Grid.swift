import SwiftUI

// MARK: - Grid
// Coordinate grid drawn by `EarthGridLayer` — meridians, parallels,
// pole + RA labels. Thin, desaturated tint so the grid sits behind
// the bright content (sun, moon, planets, stars) without competing.
extension EArtist {

    var gridColor : Color  { palette.grid }
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
                // Resolve the asset colour to concrete RGBA so this draw
                // does no main-thread asset I/O (Thread Performance
                // Checker). Few labels per frame, and the resolution is
                // cached after first use.
                .foregroundStyle(dc.resolve(gridColor)),
            at:     sc,
            anchor: .center
        )
    }
}

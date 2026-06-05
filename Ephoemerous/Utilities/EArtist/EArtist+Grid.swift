import SwiftUI

// MARK: - Grid
// Coordinate grid drawn by `EarthGridLayer` — meridians, parallels,
// pole + RA labels. Thin, desaturated tint so the grid sits behind
// the bright content (sun, moon, planets, stars) without competing.
extension EArtist {

    var gridColor : Color  { palette.grid }
    var gridWidth : Double { 0.55 }

    /// Aim-cone highlight: where the device-aim wedge falls, `EarthGridLayer`
    /// redraws the graticule in this tint, a touch thicker, so the cone
    /// reads as the grid *lighting up* — a crisp clipped patch, no fill or
    /// glow. Tied to the puck/cone colour. See `EarthGridLayer`.
    var aimConeGridColor : Color  { palette.userPuckCone }
    var aimConeGridWidth : Double { 1.1 }
    /// Edge feather (points) for the cone highlight — the highlighted grid
    /// fades out over roughly this radius at the wedge boundary instead of
    /// hard-stopping at the clip, so the line ends read soft. 0 = crisp clip.
    var aimConeFeather   : Double { 16 }

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

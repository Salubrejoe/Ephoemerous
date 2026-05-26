import SwiftUI
import LoreKit

// MARK: - Sun
// The Sun's POI badge is rendered by `drawPOILabel(.solarSystem, …)`
// in SunLayer. What lives here is the *crown* — a 12-corner squircle
// outline that breathes (scales) and rotates slowly behind the badge,
// reading as a soft animated halo around the body.
//
// `sunUnitPath` is a unit-rect (−1…1) path cached once at type-load
// and reused every frame; per-frame work is just translate + rotate
// + scale + stroke.
extension EArtist {

    var sunBorderColor    : Color   { .primary }
    var sunBodyRadius     : CGFloat { 12.0 }
    var sunBorderMinScale : CGFloat { 1.2 }      // × sunBodyRadius at breath trough
    var sunBorderMaxScale : CGFloat { 1.3 }      // × sunBodyRadius at breath peak
    var sunBorderPeriod   : Double  { 6.0 }      // seconds per breath cycle
    var sunBorderSpinRate : Double  { 0.15 }     // rad/s — slow rotation
    var sunBorderWidth    : CGFloat { 1.0 }      // stroke width in points

    /// Cached unit-rect squircle shared by the border stroke. Tweak
    /// corners / bulge here and recompile.
    private static let sunUnitPath: Path = Squircle(corners: 12, bulge: 2.8)
        .path(in: CGRect(x: -1, y: -1, width: 2, height: 2))

    /// Breathing stroked border around the sun's screen position.
    /// `sunBorderWidth / r` keeps the on-screen stroke a constant
    /// `sunBorderWidth` pt wide despite the per-frame `scaleBy`.
    func drawSunBorder(at sc: CGPoint, time t: Double, in dc: inout EGraphicContext) {
        let phase = 0.5 - 0.5 * cos(2 * .pi * t / sunBorderPeriod)
        let r     = sunBodyRadius * (sunBorderMinScale + (sunBorderMaxScale - sunBorderMinScale) * phase)
        let spin  = Angle.radians(t * sunBorderSpinRate)

        var local = dc.ctx
        local.translateBy(x: sc.x, y: sc.y)
        local.rotate(by: spin)
        local.scaleBy(x: r, y: r)
        local.stroke(Self.sunUnitPath,
                     with: .color(sunBorderColor),
                     lineWidth: sunBorderWidth / r)
    }
}

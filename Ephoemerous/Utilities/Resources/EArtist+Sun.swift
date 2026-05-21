import SwiftUI

// MARK: - Sun
// The Sun is a filled 12-corner squircle wrapped in a stroked,
// breathing, slowly-spinning border. The border is drawn first so the
// body covers its inner half — what reads as a thin crown around the
// disc is the part of the border that isn't covered by the body.
//
// `sunUnitPath` is a unit-rect (−1…1) path cached once at type-load
// and reused every frame; per-frame work is just translate + scale +
// rotate + fill / stroke.
extension EArtist {

    var sunColor          : Color   { EHRClass.G.adaptiveColor(for: .light) }
    // Spectral class G — the Sun's own. Sits in the OBAFGKM palette
    // alongside the star colours instead of jumping out as system
    // `.yellow`; swap to `EHRClass.K.color` for a warmer "setting sun"
    // feel if the cream reads too pale on your device.
    var sunBorderColor    : Color   { EHRClass.G.adaptiveColor(for: .light) }
    var sunGlowBlur       : Double  { 1.2 }      // legacy — kept for the commented-out glow experiments
    var sunBodyRadius     : CGFloat { 12.0 }
    var sunBorderMinScale : CGFloat { 1.2 }      // × sunBodyRadius at breath trough — fully inside body
    var sunBorderMaxScale : CGFloat { 1.3 }      // × sunBodyRadius at breath peak  — visible past body
    var sunBorderPeriod   : Double  { 6.0 }      // seconds per breath cycle
    var sunBorderSpinRate : Double  { 0.15 }     // rad/s — slow rotation
    var sunBorderOpacity  : Double  { 0.3 }
    var sunBorderWidth    : CGFloat { 1.0 }      // stroke width in points (compensated for scale)
    
    // 12-corner squircle shared between body fill and border stroke.
    // Cached once — tweak corners / bulge here and recompile.
    private static let sunUnitPath: Path = Squircle(
        corners: 12,
        bulge: 2.8
    )
        .path(in: CGRect(x: -1, y: -1, width: 2, height: 2))

    func drawSun(at sc: CGPoint, in dc: inout EGraphicContext) {
        // Border first so it reads as behind the body once the body
        // covers its inner half.
        drawSunBorder(at: sc, time: dc.state.animationTime, in: &dc)
        drawSunBody(at: sc, in: &dc)
    }

    private func drawSunBody(at sc: CGPoint, in dc: inout EGraphicContext) {
        var local = dc.ctx
        local.translateBy(x: sc.x, y: sc.y)
        local.scaleBy(x: sunBodyRadius, y: sunBodyRadius)
//        local.addFilter(.brightness(0.2))
        local.fill(Self.sunUnitPath, with: .color(sunColor))
    }

    /// Breathing stroked border around the sun — 12-corner squircle
    /// outline that grows from inside the body (hidden) to a visible
    /// ring past it while rotating slowly. No blur. `sunBorderWidth / r`
    /// keeps the stroke a constant `sunBorderWidth` pt wide on screen
    /// despite the per-frame `scaleBy`.
    func drawSunBorder(at sc: CGPoint, time t: Double, in dc: inout EGraphicContext) {
        let phase = 0.5 - 0.5 * cos(2 * .pi * t / sunBorderPeriod)
        let r     = sunBodyRadius * (sunBorderMinScale + (sunBorderMaxScale - sunBorderMinScale) * phase)
        let spin  = Angle.radians(t * sunBorderSpinRate)

        var local = dc.ctx
        local.translateBy(x: sc.x, y: sc.y)
        local.rotate(by: spin)
        local.scaleBy(x: r, y: r)
//        local.addFilter(.brightness(0.2))
        local.stroke(Self.sunUnitPath,
                     with: .color(sunBorderColor),
                     lineWidth: sunBorderWidth / r)
    }
}

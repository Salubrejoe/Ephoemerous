import SwiftUI

// MARK: - Breathing ring (tap affordance)
// A static ring that slowly defocuses into a soft glow and sharpens
// back to crisp — used as a "tap me" hint around interactive bodies
// (currently the Moon). The phase uses (1 − cos)/2 so the cycle starts
// and ends fully crisp, and the whole thing is driven off the canvas
// clock — so it costs nothing per frame beyond the stroke itself.
extension EArtist {

    var breathPeriod     : Double  { 11.0 }   // seconds per crisp→blur→crisp cycle
    var breathRingGap    : CGFloat { 3.0 }    // gap between body edge and the ring
    var breathRingWidth  : CGFloat { 1.5 }    // stroke width when in focus
    var breathMaxBlur    : Double  { 6.0 }    // blur radius at the defocused peak
    var breathMinOpacity : Double  { 0.16 }   // alpha when fully blurred
    var breathMaxOpacity : Double  { 0.50 }   // alpha when crisp / well-defined

    func drawBreathingRing(at sc: CGPoint, radius: CGFloat, color: Color,
                           time t: Double, in dc: inout EGraphicContext) {
        let phase   = 0.5 - 0.5 * cos(2 * .pi * t / breathPeriod)   // 0 crisp → 1 blurred → 0
        let blur    = breathMaxBlur * phase
        let opacity = breathMaxOpacity - (breathMaxOpacity - breathMinOpacity) * phase
        let ring    = Path(ellipseIn: CGRect(x: sc.x - radius, y: sc.y - radius,
                                             width: radius * 2, height: radius * 2))

        var layer = dc.ctx
        if blur > 0.01 { layer.addFilter(.blur(radius: blur)) }
        layer.stroke(ring,
                     with: .color(color.opacity(opacity)),
                     lineWidth: breathRingWidth)
    }
}

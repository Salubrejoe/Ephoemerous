import SwiftUI
import simd

// Compass labels (S / E / N / W) sitting just inside the celestial-equator
// curve filled by HorizonLayer. The four points are 90° apart in RA, but
// the stereographic projection warps that spacing on screen — for any
// non-pole observer the projected equator is a non-circle, so E and W
// don't end up a "banal π/2" away from S around the canvas.
//
// We compute screen positions in closed form rather than going through
// `EProjection.project`, because that function's basis-vector fallback
// (`e1 = (1,0,0)` when `planeVector == (0,0,-1)`) is opposite the
// continuous limit from any nearby latitude — which would flip the cross
// by π exactly when the slerp parks the observer at NP. The formula
// below has no such discontinuity.
//
// For observer (L, λ) and cardinal RA α (in the sidereally-rotated
// frame, where S sits at α=0):
//     β     = α − λ
//     denom = 1 − cos L · cos β
//     t     = 2 / denom
//     v     = t · sin β
//     u     = −t · sin L · cos β
// then `dc.toScreen(CGPoint(x: v, y: u))` is the screen anchor; pull each
// `labelInset` points toward the canvas centre so the labels read as
// just-inside the horizon curve rather than on it.
struct CardinalLabelsLayer: EGridLayer {

    let labelFont  : Font    = .caption2.weight(.light)
    let labelColor : Color   = .secondary
    let labelInset : CGFloat = 14    // pt — pull toward canvas centre

    func draw(in dc: inout EGraphicContext) {
        let L    = dc.state.origin.latitude.radians
        let lon  = dc.state.origin.longitude.radians
        let sinL = sin(L)
        let cosL = cos(L)

        let cardinals: [(label: String, alpha: Double)] = [
            ("N",  0),
            ("E",  .pi / 2),
            ("S",  .pi),
            ("W", -.pi / 2),
        ]

        let centre = CGPoint(x: dc.size.width  / 2,
                             y: dc.size.height / 2)

        for (label, alpha) in cardinals {
            let beta  = alpha - lon
            let cosB  = cos(beta)
            let sinB  = sin(beta)
            let denom = 1 - cosL * cosB
            guard denom > 1e-6 else { continue }   // skip exact singularity
            let t = 2 / denom
            let v = t * sinB
            let u = -t * sinL * cosB

            let sc = dc.toScreen(CGPoint(x: v, y: u))
            let dx = centre.x - sc.x
            let dy = centre.y - sc.y
            let d  = sqrt(dx * dx + dy * dy)
            let pos: CGPoint = (d > 0.01)
                ? CGPoint(x: sc.x + dx / d * labelInset,
                          y: sc.y + dy / d * labelInset)
                : sc

//            dc.ctx.draw(
//                Text(label)
//                    .font(labelFont)
//                    .foregroundStyle(labelColor),
//                at:     pos,
//                anchor: .center
//            )
        }
    }
}

import SwiftUI

// Moon hand: radial line from the centre to the Moon's plate point, with
// a small ring. Geocentric longitude only — orbital inclination ignored,
// as on the real Orloj.
struct OrlojMoonHandLayer: View {
    let geometry: EOrlojGeometry

    var body: some View {
        Canvas { ctx, _ in
            let p = geometry.moonPoint
            var hand = Path()
            hand.move(to: geometry.center)
            hand.addLine(to: p)
            ctx.stroke(hand, with: .color(.primary), lineWidth: 0.75)

            let r: CGFloat = 5
            ctx.stroke(circlePath(centre: p, radius: r),
                       with: .color(.primary), lineWidth: 1.5)
        }
    }
}

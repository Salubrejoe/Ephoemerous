import SwiftUI

// Sun hand: radial line from the centre (south pole) to the Sun's plate
// point, with a small ring. The Sun sits on the ecliptic by construction.
struct OrlojSunHandLayer: View {
    let geometry: EOrlojGeometry

    var body: some View {
        Canvas { ctx, _ in
            let p = geometry.sunPoint
            var hand = Path()
            hand.move(to: geometry.center)
            hand.addLine(to: p)
            ctx.stroke(hand, with: .color(.primary), lineWidth: 1)

            let r: CGFloat = 7
            ctx.stroke(circlePath(centre: p, radius: r),
                       with: .color(.primary), lineWidth: 1.5)
        }
    }
}

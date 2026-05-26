import SwiftUI

// Rete: the ecliptic ring. An offset circle (radius 1/cos ε, centre at
// tan ε toward the summer solstice) carrying 12 zodiac-sign divisions.
// Rotates with sidereal time. The Sun always sits on this circle.
struct OrlojZodiacLayer: View {
    let geometry: EOrlojGeometry

    var body: some View {
        Canvas { ctx, _ in
            ctx.stroke(circlePath(centre: geometry.eclipticCentre,
                                   radius: geometry.eclipticRadius),
                       with: .color(.primary), lineWidth: 1.5)

            // 12 sign boundaries — short ticks toward the ecliptic centre.
            let ec = geometry.eclipticCentre
            for i in 0..<12 {
                let p = geometry.eclipticPoint(longitude: .degrees(Double(i) * 30))
                let dx = ec.x - p.x, dy = ec.y - p.y
                let len = max(hypot(dx, dy), 0.0001)
                let tick: CGFloat = 8
                var path = Path()
                path.move(to: p)
                path.addLine(to: CGPoint(x: p.x + dx / len * tick,
                                         y: p.y + dy / len * tick))
                ctx.stroke(path, with: .color(.primary), lineWidth: 1)
            }
        }
    }
}

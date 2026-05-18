import SwiftUI

// Old-Bohemian (Italian) hours — the "čtyřiadvacetník". 24 equal ticks
// that creep day to day so the 24 mark meets the Sun hand at sunset.
// Here the ring is offset by the Sun's sunset hour angle.
struct OrlojBohemianRingLayer: View {
    let geometry: EOrlojGeometry

    var body: some View {
        Canvas { ctx, _ in
            guard let hSet = geometry.sunsetHourAngle(
                declination: geometry.sunEquatorial.dec) else { return }

            let c = geometry.center
            let r = geometry.tropicCancerRadius * 1.04
            ctx.stroke(circlePath(centre: c, radius: r),
                       with: .color(.primary), lineWidth: 0.75)

            for h in 0..<24 {
                // Tick 0/24 sits at the Sun-hand direction at sunset.
                let ang = hSet + Double(h) / 24.0 * 2 * .pi
                let long: CGFloat = (h == 0) ? 12 : 6
                let dir = CGPoint(x: sin(ang), y: -cos(ang))
                let outer = CGPoint(x: c.x + dir.x * r, y: c.y + dir.y * r)
                let inner = CGPoint(x: c.x + dir.x * (r - long),
                                    y: c.y + dir.y * (r - long))
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                ctx.stroke(path, with: .color(.primary), lineWidth: 0.75)
            }
        }
    }
}

import SwiftUI

// Fixed outer ring: Roman-numeral / German (CET) dial, 24 hour ticks
// (two sets of 12). Does not rotate; the Sun hand reads mean solar time
// against it. No numerals — plain ticks only.
struct OrlojRomanDialLayer: View {
    let geometry: EOrlojGeometry

    var body: some View {
        Canvas { ctx, _ in
            let c = geometry.center
            let rOuter = geometry.tropicCancerRadius * 1.10
            ctx.stroke(circlePath(centre: c, radius: rOuter),
                       with: .color(.primary), lineWidth: 1)

            for h in 0..<24 {
                let ang = Double(h) / 24.0 * 2 * .pi          // hour angle
                let long = (h % 6 == 0) ? rOuter * 0.10 : rOuter * 0.05
                let dir = CGPoint(x: sin(ang), y: -cos(ang))   // H = 0 at top
                let outer = CGPoint(x: c.x + dir.x * rOuter,
                                    y: c.y + dir.y * rOuter)
                let inner = CGPoint(x: c.x + dir.x * (rOuter - long),
                                    y: c.y + dir.y * (rOuter - long))
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                ctx.stroke(path, with: .color(.primary), lineWidth: 1)
            }
        }
    }
}

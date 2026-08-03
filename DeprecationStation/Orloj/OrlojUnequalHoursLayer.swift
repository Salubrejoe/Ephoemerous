import SwiftUI

// Fixed tympan: unequal (planetary) hours. The day arc — between sunrise
// and sunset — is split into 12 equal parts on the Capricorn, equator and
// Cancer circles; an arc is fitted through those three points per hour line.
struct OrlojUnequalHoursLayer: View {
    let geometry: EOrlojGeometry

    private let declinations: [Angle] = [
        AstroConstants.tropicCancer,     // +ε
        .zero,                           //  equator
        AstroConstants.tropicCapricorn,  // −ε
    ]

    var body: some View {
        Canvas { ctx, _ in
            ctx.clip(to: circlePath(centre: geometry.center,
                                    radius: geometry.tropicCancerRadius))

            for k in 0...12 {
                let frac = Double(k) / 12.0
                var pts: [CGPoint] = []
                for dec in declinations {
                    guard let hSet = geometry.sunsetHourAngle(declination: dec)
                    else { continue }
                    let H = -hSet + frac * 2 * hSet   // sunrise → sunset
                    pts.append(geometry.platePoint(hourAngle: H, declination: dec))
                }
                guard pts.count >= 2 else { continue }

                var path = Path()
                if pts.count == 3,
                   let cir = EOrlojGeometry.circle(through: pts[0], pts[1], pts[2]) {
                    path = arcPolyline(centre: cir.centre, radius: cir.radius,
                                       from: pts[0], through: pts[1], to: pts[2])
                } else {
                    path.move(to: pts.first!)
                    path.addLine(to: pts.last!)
                }
                ctx.stroke(path, with: .color(.primary), lineWidth: 0.75)
            }
        }
    }
}

// Polyline along the circle arc from `a` to `b`, taking the side that
// passes through `mid`.
private func arcPolyline(centre o: CGPoint, radius r: CGFloat,
                         from a: CGPoint, through mid: CGPoint,
                         to b: CGPoint) -> Path {
    func angle(_ p: CGPoint) -> Double { atan2(Double(p.y - o.y), Double(p.x - o.x)) }
    func norm(_ x: Double) -> Double {
        let t = x.truncatingRemainder(dividingBy: 2 * .pi)
        return t < 0 ? t + 2 * .pi : t
    }
    let aA = angle(a), aM = angle(mid), aB = angle(b)
    // Sweep CCW from aA to aB; flip if that path misses the mid point.
    var sweep = norm(aB - aA)
    let toMid = norm(aM - aA)
    if toMid > sweep { sweep -= 2 * .pi }

    var path = Path()
    let steps = 24
    for i in 0...steps {
        let t = aA + sweep * Double(i) / Double(steps)
        let p = CGPoint(x: o.x + r * CGFloat(cos(t)),
                        y: o.y + r * CGFloat(sin(t)))
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    return path
}

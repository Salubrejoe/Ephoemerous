import SwiftUI

// Fixed background plate: the three concentric declination circles.
// Tropic of Capricorn (inner) and Cancer (outer) bound the zodiac band;
// the equator is the unit circle.
struct OrlojPlateLayer: View {
    let geometry: EOrlojGeometry

    var body: some View {
        Canvas { ctx, _ in
            let c = geometry.center
            for r in [geometry.tropicCapricornRadius,
                      geometry.tropicCancerRadius] {
                ctx.stroke(circlePath(centre: c, radius: r),
                           with: .color(.primary), lineWidth: 1)
            }
            ctx.stroke(circlePath(centre: c, radius: geometry.equatorRadius),
                       with: .color(.primary), lineWidth: 2)
        }
    }
}

func circlePath(centre: CGPoint, radius: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                           width: radius * 2, height: radius * 2))
}

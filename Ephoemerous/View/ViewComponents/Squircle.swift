import SwiftUI

// MARK: - Squircle
// A superellipse generalised to an arbitrary number of corners — a Lamé
// curve in polar form (Gielis superformula, simplified):
//
//   r(θ) = ( |cos(n·θ/4)|^p + |sin(n·θ/4)|^p )^(-1/p)
//
// `corners` (n) sets the rotational symmetry; `bulge` (p) controls how
// square-vs-round each corner sits:
//   • bulge == 2          → circle (regardless of corners)
//   • corners == 4, p == 4 → classic squircle
//   • bulge → ∞           → approaches a regular n-gon
//
// See https://thatsmaths.com/2016/07/14/squircles/ for the squircle case.
struct Squircle: Shape {

    var corners  : Int     = 4
    var bulge    : CGFloat = 4
    var rotation : Angle   = .zero

    // Animate `bulge` smoothly; `corners` is discrete and not animated.
    var animatableData: CGFloat {
        get { bulge }
        set { bulge = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (i, p) in vertices(in: rect).enumerated() {
            if i == 0 { path.move   (to: p) }
            else      { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    /// Sampled rim of the squircle. Useful when you want to feed the points
    /// through your own drawing pipeline (e.g. `EGraphicContext.strokeCurve`)
    /// rather than letting SwiftUI fill/stroke a `Path` directly.
    func vertices(in rect: CGRect, segments: Int = 240) -> [CGPoint] {
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width  / 2
        let ry = rect.height / 2
        let n  = CGFloat(corners)
        let p  = max(bulge, 0.0001)
        let α  = CGFloat(rotation.radians)

        var pts = [CGPoint]()
        pts.reserveCapacity(segments + 1)
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments) * 2 * .pi
            let r = lameRadius(angle: t, corners: n, bulge: p)
            pts.append(
                CGPoint(x: cx + rx * r * cos(t + α),
                        y: cy + ry * r * sin(t + α))
            )
        }
        return pts
    }

    private func lameRadius(angle t: CGFloat, corners n: CGFloat, bulge p: CGFloat) -> CGFloat {
        let a = abs(cos(n * t / 4))
        let b = abs(sin(n * t / 4))
        return pow(pow(a, p) + pow(b, p), -1 / p)
    }
}

#Preview {
    let bulges : [CGFloat] = [2, 4, 8, 20]
    let nCorns : [Int]     = [3, 4, 5, 6, 8]

    return VStack(spacing: 12) {
        ForEach(bulges, id: \.self) { p in
            HStack(spacing: 12) {
                ForEach(nCorns, id: \.self) { n in
                    Squircle(corners: n, bulge: p)
                        .fill(.yellow)
                        .frame(width: 44, height: 44)
                }
            }
        }
    }
    .padding()
    .background(.black)
}

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

    var corners : Int     = 4
    var bulge   : CGFloat = 4

    // Animate `bulge` smoothly; `corners` is discrete and not animated.
    var animatableData: CGFloat {
        get { bulge }
        set { bulge = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width  / 2
        let ry = rect.height / 2
        let n  = CGFloat(corners)
        let p  = max(bulge, 0.0001)

        let segments = 240
        var path     = Path()

        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments) * 2 * .pi
            let r = lameRadius(angle: t, corners: n, bulge: p)
            let x = cx + rx * r * cos(t)
            let y = cy + ry * r * sin(t)
            if i == 0 { path.move   (to: CGPoint(x: x, y: y)) }
            else      { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
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

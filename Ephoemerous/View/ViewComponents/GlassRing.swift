import SwiftUI

// MARK: - GlassRing
// A glass annulus: a tinted glass disc punched hollow by a destination-out
// inner circle, leaving a rim `lineWidth` thick at the outer edge.
//
// Viewport-fixed by design: drive `radius` from a fixed value, never bind
// it to `renderedScale` inside a view that is a ZStack sibling of the
// gesture layer — a scale-sized rigid `.frame` there silently re-creates
// the layout feedback loop the UIKit gesture migration removed.
struct GlassRing: View {

    let radius    : Double
    let lineWidth : Double
    let tint      : Color

    init(radius: Double, lineWidth: Double, tint: Color = .clear) {
        self.radius    = radius
        self.lineWidth = lineWidth
        self.tint      = tint
    }

    var body: some View {
        Circle()
            .frame(width: 2 * radius, height: 2 * radius)
            .glassEffect(.clear.tint(tint))
            .mask(annulusMask)
    }

    // Solid disc with the inner disc cut out (destinationOut), so only the
    // outer `lineWidth`-thick band survives.
    private var annulusMask: some View {
        Circle()
            .frame(width: 2 * radius, height: 2 * radius)
            .overlay(
                Circle()
                    .frame(width:  2 * (radius - lineWidth),
                           height: 2 * (radius - lineWidth))
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
    }
}

#Preview {
    GlassRing(radius: 80, lineWidth: 6, tint: .orange)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
}

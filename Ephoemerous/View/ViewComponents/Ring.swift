import SwiftUI

// MARK: - Ring
// A material annulus: an ultraThinMaterial disc punched hollow by a
// destination-out inner circle, leaving a rim `lineWidth` thick at the
// outer edge. Same shape as GlassRing, plain material instead of glass.
//
// Viewport-fixed by design (see GlassRing): never bind `radius` to
// `renderedScale` in a gesture-sibling view.
struct Ring: View {

    let radius    : Double
    let lineWidth : Double

    init(radius: Double, lineWidth: Double) {
        self.radius    = radius
        self.lineWidth = lineWidth
    }

    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 2 * radius, height: 2 * radius)
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
    Ring(radius: 80, lineWidth: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
}

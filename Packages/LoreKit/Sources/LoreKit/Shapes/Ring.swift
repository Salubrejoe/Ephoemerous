import SwiftUI

// MARK: - Ring
// Annulus shape — outer circle with a concentric circular hole.
// `thickness` is the ring's stroke width (outerRadius − innerRadius);
// the outer radius itself comes from the smaller side of the bounding
// rect, so the ring stays centred and circular in any frame.
//
//   • `thickness ≥ outerRadius`  → solid disc.
//   • `thickness = 0`            → empty path (degenerate).
//
// Implementation uses `Path.subtracting(_:)` rather than even-odd
// fill — the result is a geometrically-correct annulus that fills
// cleanly under SwiftUI's default non-zero winding rule, with no
// `FillStyle(eoFill: true)` tax at the call site. Works the same way
// when fed to `.fill(...)`, `.stroke(...)`, `.clipShape(...)`, or
// `.glassEffect(_:in: Ring(...))`.
public struct Ring: Shape {

    public var thickness: CGFloat

    public init(thickness: CGFloat = 8) {
        self.thickness = thickness
    }

    /// Animate `thickness` smoothly when the ring's weight changes.
    public var animatableData: CGFloat {
        get { thickness }
        set { thickness = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let outer  = min(rect.width, rect.height) / 2
        let inner  = max(0, outer - thickness)
        let centre = CGPoint(x: rect.midX, y: rect.midY)

        let outerCircle = Path(ellipseIn: CGRect(
            x:      centre.x - outer,
            y:      centre.y - outer,
            width:  outer * 2,
            height: outer * 2
        ))
        let innerCircle = Path(ellipseIn: CGRect(
            x:      centre.x - inner,
            y:      centre.y - inner,
            width:  inner * 2,
            height: inner * 2
        ))

        return outerCircle.subtracting(innerCircle)
    }
}

#Preview {
    VStack(spacing: 20) {
        Ring(thickness: 4)
            .fill(.orange)
            .frame(width: 120, height: 120)

        Ring(thickness: 12)
            .fill(.indigo.gradient)
            .frame(width: 120, height: 120)

        Ring(thickness: 40)
            .fill(.green)
            .frame(width: 120, height: 120)
    }
    .padding()
}

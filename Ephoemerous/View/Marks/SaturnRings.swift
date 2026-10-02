import SwiftUI

// MARK: - SaturnRings
// Saturn's ring set around its POI badge — the one planet whose badge can
// say what it is. Drawn in two passes so it reads as 3D: the BACK half sits
// behind the globe, the FRONT half crosses over it. Same species as every
// badge: a pale cream band, the near-black casing that does the legibility
// work against a busy sky, and the Cassini Division as a single dark hairline
// (the detail that says "Saturn", not "a ringed thing").
//
// Geometry is in units of the badge diameter `d`, so the rings scale with
// the badge (including the promoted pin's enlargement). The rings overhang
// the badge's layout frame — the view is meant to sit in a `.background` /
// `.overlay`, so the badge keeps its size and its precise anchor.
struct SaturnRings: View {

    enum Half { case back, front }

    let half:      Half
    /// Badge diameter — every ring dimension is a fraction of it.
    let diameter:  CGFloat
    let fill:      AnyShapeStyle
    let casing:    Color
    /// Casing weight, already scale-compensated by the caller (same value
    /// the badge strokes its disc with).
    let lineWidth: CGFloat

    private var d: CGFloat { diameter }

    var body: some View {
        let a = Artist.shared
        ZStack {
            RingBand(outer: a.saturnRingOuter, inner: a.saturnRingInner)
                .fill(fill, style: FillStyle(eoFill: true))
            Ellipse()
                .stroke(casing, lineWidth: lineWidth)
                .frame(width: d * a.saturnRingOuter.width, height: d * a.saturnRingOuter.height)
            Ellipse()
                .stroke(casing, lineWidth: lineWidth * 0.6)
                .frame(width: d * a.saturnRingInner.width, height: d * a.saturnRingInner.height)
            Ellipse()
                .stroke(casing.opacity(0.75), lineWidth: lineWidth * 0.27)
                .frame(width: d * a.saturnCassini.width, height: d * a.saturnCassini.height)
        }
        .frame(width: d * 2.2, height: d * 2.2)
        .mask(alignment: half == .back ? .top : .bottom) {
            // A hair past the equator so the two halves meet without a seam.
            Rectangle().frame(height: d * 1.1 + d * 0.02)
        }
        .rotationEffect(a.saturnRingTilt)
        .allowsHitTesting(false)
    }
}

// MARK: - RingBand
/// The annulus between two centred ellipses (even-odd fill). Sizes are
/// fractions of the badge diameter; the shape assumes a frame of 2.2·d.
private struct RingBand: Shape {
    let outer: CGSize
    let inner: CGSize

    func path(in rect: CGRect) -> Path {
        let d = rect.width / 2.2
        var p = Path()
        p.addEllipse(in: ellipse(outer, d: d, in: rect))
        p.addEllipse(in: ellipse(inner, d: d, in: rect))
        return p
    }

    private func ellipse(_ s: CGSize, d: CGFloat, in rect: CGRect) -> CGRect {
        CGRect(x: rect.midX - s.width * d / 2, y: rect.midY - s.height * d / 2,
               width: s.width * d, height: s.height * d)
    }
}

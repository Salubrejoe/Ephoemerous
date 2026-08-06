import SwiftUI

// MARK: - MoonPhaseShape
// The Moon's lit silhouette — the badge's actual outline, not a mask over
// a disc.
//
// THE REASON IT'S A SHAPE: the casing has to trace the CRESCENT. Case a
// full disc and fill only the lit part and it reads as a full moon with a
// stain on it; the dark limb is invisible against a night sky anyway, so
// the honest mark is the lit sliver alone, cased along its own edge. Only
// a real path can be both filled and stroked like that.
//
// THE GEOMETRY: two half-ellipses sharing their endpoints at the poles.
//   • the OUTER LIMB — a semicircle of radius r, always bulging to the
//     lit side; the Moon's actual edge.
//   • the TERMINATOR — a half-ellipse of signed horizontal semi-axis
//     r·(1 − 2f). It is a projected circle seen at an angle, which is why
//     an ellipse is exact here and not an approximation:
//        f < ½  →  positive, bulges toward the lit side  → crescent
//        f = ½  →  zero, a straight line                 → quarter
//        f > ½  →  negative, bulges to the dark side     → gibbous
//
// Each half is two cubic segments with the standard circle constant, so
// the whole outline is four curves and interpolates smoothly — which is
// what lets `animatableData` ease the terminator as the date scrubs.
struct MoonPhaseShape: Shape {

    var phase: LunarPhase

    /// Animate on the fraction alone. The lit SIDE can't be tweened — a
    /// moon doesn't sweep through "lit from the front" on its way from
    /// waxing to waning; it passes through new, where the fraction is
    /// already ~0 and the flip is invisible.
    var animatableData: Double {
        get { phase.illuminatedFraction }
        set { phase = LunarPhase(illuminatedFraction: newValue,
                                isWaxing:            phase.isWaxing,
                                southernView:        phase.southernView) }
    }

    /// Cubic approximation constant for a quarter ellipse.
    private static let kappa: CGFloat = 0.5522847498307936

    func path(in rect: CGRect) -> Path {
        let r      = min(rect.width, rect.height) / 2
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let top    = CGPoint(x: centre.x, y: centre.y - r)
        let bottom = CGPoint(x: centre.x, y: centre.y + r)

        var path = Path()

        // New moon: no sliver worth drawing. Hand back the full disc so
        // the caller can render it as an unfilled outline — earthshine,
        // and the label stays anchored instead of vanishing for two days
        // out of every month.
        guard !phase.isNew else {
            path.addEllipse(in: CGRect(x: centre.x - r, y: centre.y - r,
                                       width: r * 2,   height: r * 2))
            return path
        }

        let f       = min(max(phase.illuminatedFraction, 0), 1)
        let litSign: CGFloat = phase.litOnTrailingSide ? 1 : -1
        let limb    = litSign * r                       // outer edge
        let term    = litSign * r * CGFloat(1 - 2 * f)  // terminator

        path.move(to: top)
        appendHalf(&path, from: top, to: bottom, centre: centre, r: r, width: limb)
        appendHalf(&path, from: bottom, to: top, centre: centre, r: r, width: term)
        path.closeSubpath()
        return path
    }

    /// One half-ellipse between the poles, bulging `width` horizontally
    /// (signed — negative bulges the other way). Two quarter-arcs, each a
    /// cubic, meeting at the widest point.
    private func appendHalf(_ path: inout Path,
                            from start:  CGPoint,
                            to end:      CGPoint,
                            centre:      CGPoint,
                            r:           CGFloat,
                            width:       CGFloat) {
        let k     = Self.kappa
        let waist = CGPoint(x: centre.x + width, y: centre.y)
        // Vertical direction of travel: +1 going down the page, −1 up.
        let dir: CGFloat = end.y > start.y ? 1 : -1

        path.addCurve(to:       waist,
                      control1: CGPoint(x: start.x + width * k, y: start.y),
                      control2: CGPoint(x: waist.x,             y: waist.y - r * k * dir))
        path.addCurve(to:       end,
                      control1: CGPoint(x: waist.x,           y: waist.y + r * k * dir),
                      control2: CGPoint(x: end.x + width * k, y: end.y))
    }
}

#if DEBUG
// The full lunation, left to right — new through full and back. Every one
// of these has to read at badge size, so the top row is 18pt (what the
// Moon POI actually ships at) and the bottom row is the same shapes large
// enough to check the curves.
#Preview("Lunation") {
    let steps: [(Double, Bool)] = [
        (0.00, true), (0.15, true), (0.35, true), (0.50, true), (0.72, true),
        (0.95, true), (1.00, true), (0.72, false), (0.50, false), (0.15, false)
    ]

    func moon(_ f: Double, _ waxing: Bool, south: Bool, size: CGFloat) -> some View {
        let phase = LunarPhase(illuminatedFraction: f, isWaxing: waxing, southernView: south)
        return MoonPhaseShape(phase: phase)
            .fill(phase.isNew ? AnyShapeStyle(.clear) : AnyShapeStyle(Color.white))
            .overlay(MoonPhaseShape(phase: phase).stroke(.white.opacity(0.9), lineWidth: 1))
            .frame(width: size, height: size)
    }

    return ZStack {
        Color(red: 0.05, green: 0.08, blue: 0.16)
        VStack(alignment: .leading, spacing: 20) {
            Text("18pt — actual badge size")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(0..<steps.count, id: \.self) { i in
                    moon(steps[i].0, steps[i].1, south: false, size: 18)
                }
            }
            Text("northern")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(0..<steps.count, id: \.self) { i in
                    moon(steps[i].0, steps[i].1, south: false, size: 42)
                }
            }
            // Sydney sees every one of these mirrored.
            Text("southern — same instants, flipped")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(0..<steps.count, id: \.self) { i in
                    moon(steps[i].0, steps[i].1, south: true, size: 42)
                }
            }
        }
        .padding(20)
    }
    .frame(width: 580, height: 300)
    .environment(\.colorScheme, .dark)
}
#endif

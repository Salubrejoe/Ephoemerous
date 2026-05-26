import SwiftUI

// MARK: - Constellation lines
// Thin, low-contrast strokes between the figure-stars of each
// constellation. Each segment is *inset* on both ends by a per-star
// breathing gap so the line never touches the star dot.
extension EArtist {

    var constellationLineColor : Color  { .secondary }
    var constellationLineWidth : Double { 0.6 }

    /// Centre-to-centre spacing between dots along a stick-figure
    /// segment. Tunable — increase for sparser, decrease for denser.
    var constellationLineDotPitch : Double { 2.4 }

    /// Extra screen-space gap added to each end of a segment, *on top*
    /// of the projected star radius. Keeps a visible halo of bare canvas
    /// around every star regardless of zoom.
    var constellationLineGapPad    : Double { 0.2 }

    /// Magnitude cutoff above which we don't bother drawing a segment.
    /// Set generously — figure-stars are almost always Vmag < 4 anyway.
    var constellationLineMagCutoff : Double { 6.5 }

    /// Trim a screen-space segment by `inset` points on each end and
    /// stroke what's left. Returns silently if the segment is shorter
    /// than the combined inset (i.e. the two stars are visually
    /// touching) — drawing nothing is the right call there.
    func drawConstellationSegment(from a: CGPoint, to b: CGPoint,
                                  insetA: Double, insetB: Double,
                                  in dc: inout EGraphicContext) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = sqrt(dx * dx + dy * dy)
        let needed = insetA + insetB
        guard len > needed + 0.5 else { return }
        let ux = dx / len
        let uy = dy / len
        let p0 = CGPoint(x: a.x + ux * insetA, y: a.y + uy * insetA)
        let p1 = CGPoint(x: b.x - ux * insetB, y: b.y - uy * insetB)

        var path = Path()
        path.move(to: p0)
        path.addLine(to: p1)
        // Dotted stroke: `dash: [0]` with `.round` cap renders each
        // dash as a single round dot of diameter = lineWidth,
        // spaced by `constellationLineDotPitch`. Same colour, just
        // rhythmised across the segment.
        dc.ctx.stroke(
            path,
            with: .color(constellationLineColor),
            style: StrokeStyle(
                lineWidth: constellationLineWidth,
                lineCap:   .round,
                dash:      [0, constellationLineDotPitch]
            )
        )
    }
}

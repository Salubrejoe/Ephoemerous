import SwiftUI

// MARK: - Constellation lines
// Thin, low-contrast strokes between the figure-stars of each
// constellation. Each segment is *inset* on both ends by a per-star
// breathing gap so the line never touches the star dot.
extension EArtist {

    var constellationLineColor : Color  { palette.constellationLine }
    var constellationLineWidth : Double { 1.0 }

    /// Stroke width for a favourited constellation's stick-figure
    /// lines. Slightly bumped over the normal width so the solid
    /// (un-dotted) emphasis reads cleanly.
    var constellationFavouriteLineWidth : Double { 1.0 }

    /// Hand-drawn "squiggle" flare for the SELECTED constellation: each
    /// segment becomes a gentle sine wave instead of a straight line.
    /// `Amplitude` is the perpendicular wiggle in points; `Wavelength` the
    /// screen distance per full wave (so denser figures wiggle more times).
    var constellationSquiggleAmplitude  : Double { 0.0 }
    var constellationSquiggleWavelength : Double { 16 }

    /// Centre-to-centre spacing between dots along a stick-figure
    /// segment. Tunable — increase for sparser, decrease for denser.
    var constellationLineDotPitch : Double { 2.4 }

    /// Extra screen-space gap added to each end of a segment, *on top*
    /// of the projected star radius. Keeps a visible halo of bare canvas
    /// around every star regardless of zoom.
    var constellationLineGapPad    : Double { 2.7 }

    /// Magnitude cutoff above which we don't bother drawing a segment.
    /// Set generously — figure-stars are almost always Vmag < 4 anyway.
    var constellationLineMagCutoff : Double { 6.5 }

    /// Trim a screen-space segment by `inset` points on each end and
    /// stroke what's left. Returns silently if the segment is shorter
    /// than the combined inset (i.e. the two stars are visually
    /// touching) — drawing nothing is the right call there.
    func drawConstellationSegment(from a: CGPoint, to b: CGPoint,
                                  insetA: Double, insetB: Double,
                                  color: Color,
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
            with: .color(color),
            style: StrokeStyle(
                lineWidth: constellationLineWidth,
                lineCap:   .round,
                dash:      [0, constellationLineDotPitch]
            )
        )
    }

    /// Solid, fully-coloured variant for the stick-figures of a
    /// favourited constellation — same trim/inset logic as the
    /// neutral helper above, but no dash (continuous line) and
    /// tinted to the myth gradient top, matching the heart on the
    /// POI badge. Net effect: the favourited constellation reads
    /// as one cohesive coloured shape (figure + badge + heart), the
    /// rest of the sky stays in its quiet dotted grey register.
    func drawConstellationSegmentFavourite(from a: CGPoint, to b: CGPoint,
                                           insetA: Double, insetB: Double,
                                           color: Color,
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
        dc.ctx.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: constellationFavouriteLineWidth,
                lineCap:   .round
            )
        )
    }

    /// Hand-drawn squiggle variant for the SELECTED constellation — same
    /// trim/inset as the others, but the trimmed span is drawn as a sine
    /// wave offset perpendicular to the segment. An INTEGER number of
    /// half-waves keeps the offset zero at both ends, so it still meets each
    /// star cleanly. Scoped to the selected figure (a handful of segments),
    /// so the extra points are negligible; no animation, so no redraw tick.
    func drawConstellationSegmentSquiggle(from a: CGPoint, to b: CGPoint,
                                          insetA: Double, insetB: Double,
                                          color: Color,
                                          in dc: inout EGraphicContext) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = sqrt(dx * dx + dy * dy)
        let needed = insetA + insetB
        guard len > needed + 0.5 else { return }

        let ux = dx / len, uy = dy / len          // along
        let px = -uy,      py = ux                 // perpendicular
        let p0 = CGPoint(x: a.x + ux * insetA, y: a.y + uy * insetA)
        let span = len - needed

        // Integer half-waves so offset = 0 at t = 0 and t = 1.
        let halfWaves = max(1.0, (2 * span / constellationSquiggleWavelength).rounded())
        let amp   = constellationSquiggleAmplitude
        let steps = max(12, Int(halfWaves * 8))

        var path = Path()
        for i in 0...steps {
            let t     = Double(i) / Double(steps)
            let along = span * t
            let off   = amp * sin(halfWaves * .pi * t)
            let pt = CGPoint(x: p0.x + ux * along + px * off,
                             y: p0.y + uy * along + py * off)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        dc.ctx.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: constellationFavouriteLineWidth,
                lineCap:   .round,
                lineJoin:  .round
            )
        )
    }
}

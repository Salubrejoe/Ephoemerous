import SwiftUI

// MARK: - Star field style
// The ONE way a plain field star is drawn — the app's sky (`StarsCanvas`),
// the Home Screen postcard and the share card (`SkySnapshot`) all draw
// through `drawFieldStar`, so a tweak here lands on every surface at once
// instead of drifting apart the way the widget's copy did.
//
// What lives here is STYLE: shape, size by magnitude, brightness, glow,
// ink. How DEEP the field goes is each surface's own call — the app ties it
// to the zoom, the widget to the tile's size.
extension Artist {

    // MARK: Ink
    // Colour means "tappable": the field is grey ink, and a star's spectral
    // colour blooms only when its own mark (the pentagon, then the badge)
    // takes over. A star no zoom will ever name sits a step quieter than
    // one waiting for its mark (`fieldStarColor` / `anonymousStarColor`).

    /// The field ink for a star — named (tappable once zoomed in) or not.
    func fieldStarInk(named: Bool) -> Color {
        named ? fieldStarColor : anonymousStarColor
    }

    // MARK: Size ▼ TWEAK ▼
    // How much dots grow with the camera scale.
    //   zoomExp 0 = fixed size, 1 = grows with the zoom (balloons),
    //   ~0.5 = bigger at high scale with a gentle commit adjustment.
    private var starZoomExp:    CGFloat { 0.5 }
    /// Default / minimum scale → growth factor 1.
    private var starZoomAnchor: CGFloat { 90 }
    /// Clamp on the growth so max-zoom dots don't balloon.
    private var starZoomCap:    CGFloat { 4 }
    /// Largest radius zoom may grow a field dot to — under the named-star
    /// pentagon's 2.6, so the stars you can tap read as a different species.
    var fieldDotMaxRadius:      CGFloat { 1.7 }

    private func starZoomFactor(_ scale: CGFloat) -> CGFloat {
        min(starZoomCap, pow(max(scale, starZoomAnchor) / starZoomAnchor, starZoomExp))
    }

    /// Dot radius: brighter → bigger (a steep curve, so the bright stars
    /// carry the field), times a sub-linear growth with `scale`, capped so
    /// a field dot never outgrows the tappable marks. A star already bigger
    /// than the cap at rest keeps its resting size.
    func fieldStarRadius(magnitude m: Double, scale: CGFloat) -> CGFloat {
        let base = CGFloat(max(0.5, (6.5 - m) * 0.42))
        return min(base * starZoomFactor(scale), max(base, fieldDotMaxRadius))
    }

    // MARK: Brightness ▼ TWEAK ▼
    // Faint stars dim out so the field reads as depth, not noise. The
    // bright end saturates early — a 1st-magnitude star is flat — and the
    // ramp spends its range on the faint half, where depth actually reads.
    private var starMagnitudeSpan: Double { 4.0 }
    private var starBrightLift:    Double { 7.0 }
    private var starFaintFloor:    Double { 0.35 }

    func fieldStarOpacity(magnitude m: Double) -> Double {
        min(1, max(starFaintFloor, (starBrightLift - m) / starMagnitudeSpan))
    }

    // MARK: Glow ▼ TWEAK ▼
    // The brightest few glow — the cue that they're light sources, not
    // dots. Fades out as the dots finish growing so it never blooms to
    // soup, and only above the horizon: a star under the ground isn't
    // shining on anyone.

    /// Stars brighter than this get a halo (~90 of them).
    var starGlowBelowMagnitude: Double  { 2.5 }
    /// Halo radius as a multiple of the dot's.
    private var starGlowReach:  CGFloat { 4 }
    /// Halo opacity at its centre, at the default zoom.
    private var starGlowStrength: Double { 0.35 }

    /// 1 at the default zoom, falling to 0 as the dots finish growing.
    func fieldStarGlow(scale: CGFloat) -> Double {
        Double(max(0, 1 - (starZoomFactor(scale) - 1) / 1.5))
    }

    // MARK: Draw

    /// One field star at `point`: its glow (bright, above the horizon),
    /// then the pentagon squircle in its ink. `reveal` fades a star that
    /// is just crossing the surface's depth limit. `gain` lifts a whole
    /// surface's field at once — a small static tile needs a firmer field
    /// than the live sky to read as anything but haze. `sizeScale` shrinks
    /// it for a surface whose field is scenery (the Orloj's dial).
    /// `aboveHorizon` is only evaluated for the few bright enough to glow.
    func drawFieldStar(_ ctx: GraphicsContext,
                       at point:              CGPoint,
                       magnitude m:           Double,
                       named:                 Bool,
                       scale:                 CGFloat,
                       reveal:                Double = 1,
                       gain:                  Double = 1,
                       sizeScale:             CGFloat = 1,
                       aboveHorizon:          @autoclosure () -> Bool) {
        let r   = fieldStarRadius(magnitude: m, scale: scale) * sizeScale
        let ink = fieldStarInk(named: named)
        if m < starGlowBelowMagnitude {
            let glow = fieldStarGlow(scale: scale)
            if glow > 0.01, aboveHorizon() {
                let g = r * starGlowReach
                ctx.fill(Path(ellipseIn: CGRect(x: point.x - g, y: point.y - g, width: g * 2, height: g * 2)),
                         with: .radialGradient(Gradient(colors: [ink.opacity(starGlowStrength * glow), .clear]),
                                               center: point, startRadius: 0, endRadius: g))
            }
        }
        ctx.fill(starPath(at: point, radius: r),
                 with: .color(ink.opacity(min(1, fieldStarOpacity(magnitude: m) * reveal * gain))))
    }

    // MARK: Figures
    // Constellation lines the star-atlas way, on every surface that draws
    // them (the sky, the postcard, the Orloj, the sheet header): each line
    // STOPS SHORT of its stars, so stars read as nodes and lines as the
    // connections between them — never skewered, never a blob where three
    // meet. Solid hairlines; dotted was one more speck in a field of them.

    /// ▼ TWEAK the figures ▼
    /// Hairline weight of a figure's line.
    var figureLineWidth:  CGFloat { 0.6 }
    /// Sky left between a star's edge and the line that reaches for it.
    var figureGapMargin:  CGFloat { 2.5 }
    /// Shortest stretch of line still worth drawing between two gaps.
    var figureMinimumRun: CGFloat { 3 }

    /// The visible part of the line a → b, pulled back `gapA` from a and
    /// `gapB` from b; `nil` when the gaps leave too little to draw.
    func figureSegment(from a: CGPoint, to b: CGPoint,
                       gapA: CGFloat, gapB: CGFloat) -> (CGPoint, CGPoint)? {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > gapA + gapB + figureMinimumRun else { return nil }
        let ux = dx / length, uy = dy / length
        return (CGPoint(x: a.x + ux * gapA, y: a.y + uy * gapA),
                CGPoint(x: b.x - ux * gapB, y: b.y - uy * gapB))
    }
}

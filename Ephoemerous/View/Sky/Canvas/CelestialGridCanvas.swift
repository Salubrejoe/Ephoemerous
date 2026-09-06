import SwiftUI
import simd

// MARK: - SkyLabGridCanvas
// The equatorial grid as a Canvas — the cheap, many-stroke layer that
// SHOULD stay Canvas (thousands of strokes/dots are its sweet spot). It
// renders at the camera's COMMITTED transform; the shared parent
// transform in SkyLabView handles live pan / zoom, so this draw closure
// only re-runs when the committed camera actually changes (a settle, a
// date / origin move), never mid-gesture.
struct CelestialGridCanvas: View, Equatable {
    let camera: SkyCamera   // Equatable synthesised → `.equatable()` skips
                               // the redraw while the camera is frozen.

    /// Grid pitch, in degrees — the spacing of the BRIGHT lines. Both
    /// families read it, so the graticule stays square however coarse it
    /// gets. ▼ TWEAK ▼
    private static let pitchDeg: Double = 30

    /// Half-pitch lines are drawn between them at this fraction of the
    /// grid colour: enough structure to read as a grid in the wide bare
    /// band either side of the equator, without doubling the noise.
    /// ▼ TWEAK ▼
    private static let minorOpacity: Double = 0.5

    // Parallels — constant declination. BOTH POLES are excluded from either
    // tier: a pole is a degenerate parallel (every sample projects to the
    // same point), so it spends a full curve's worth of projections drawing
    // a dot. The `from`/`through` pair excludes them by construction, at any
    // pitch, and keeps the set symmetric about the equator.

    private static let majorParallelsDeg: [Double] = stride(from:    -90 + CelestialGridCanvas.pitchDeg,
                                                            through:  90 - CelestialGridCanvas.pitchDeg,
                                                            by:            CelestialGridCanvas.pitchDeg).map { $0 }

    private static let minorParallelsDeg: [Double] = stride(from:    -90 + CelestialGridCanvas.pitchDeg / 2,
                                                            through:  90 - CelestialGridCanvas.pitchDeg / 2,
                                                            by:            CelestialGridCanvas.pitchDeg).map { $0 }

    // Meridians — constant RA, the same pitch expressed in hours (1h = 15°),
    // the minor tier offset by half a pitch so it bisects the major one.
    // Half-open: each meridian is a pole-to-pole HALF circle, so the far half
    // of every great circle is already drawn by its opposite number.

    private static let majorMeridianHours: [Double] = stride(from: 0,
                                                             to:   24,
                                                             by:   CelestialGridCanvas.pitchDeg / 15).map { $0 }

    private static let minorMeridianHours: [Double] = stride(from: CelestialGridCanvas.pitchDeg / 30,
                                                             to:   24,
                                                             by:   CelestialGridCanvas.pitchDeg / 15).map { $0 }

    var body: some View {
        Canvas {
            ctx,
            _ in
            let color = Artist.shared.gridColor
            let width = Artist.shared.gridWidth

            ctx.stroke(path(parallels: Self.majorParallelsDeg,
                            meridians: Self.majorMeridianHours),
                       with:      .color(color),
                       lineWidth: width)

            ctx.stroke(path(parallels: Self.minorParallelsDeg,
                            meridians: Self.minorMeridianHours),
                       with:      .color(color.opacity(Self.minorOpacity)),
                       lineWidth: width)
        }
    }

    /// One tier of the graticule as a single path — every curve in it is
    /// stroked with one colour, so the tiers are two paths, not two colours
    /// per curve.
    private func path(parallels: [Double], meridians: [Double]) -> Path {
        var path = Path()

        // Parallels — constant declination, RA sweeps 0…2π.
        for decDeg in parallels {
            appendCurve(to: &path) { t in
                Precession.equatorialVector(ra:  .radians(t * 2 * .pi),
                                             dec: .degrees(decDeg))
            }
        }
        // Meridians — constant RA, Dec sweeps −90°…90°.
        for h in meridians {
            appendCurve(to: &path) { t in
                Precession.equatorialVector(ra:  .radians(h / 24 * 2 * .pi),
                                             dec: .radians((t - 0.5) * .pi))
            }
        }
        return path
    }

    /// Sample a sky curve, project each point, and append the on-screen
    /// polyline — breaking the path across back-side projection jumps.
    private func appendCurve(to path: inout Path,
                             point: (Double) -> SIMD3<Double>) {
        let steps = 120
        var prev: CGPoint? = nil
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            guard let sc = camera.screen(equatorial: point(t)) else { prev = nil; continue }
            if let p = prev {
                let dx = sc.x - p.x, dy = sc.y - p.y
                if dx * dx + dy * dy < 80_000 { path.addLine(to: sc) }
                else                          { path.move(to: sc) }
            } else {
                path.move(to: sc)
            }
            prev = sc
        }
    }
}

#if DEBUG
#Preview("Grid") {
    PreviewSky.night { CelestialGridCanvas(camera: PreviewSky.camera) }
}
#endif

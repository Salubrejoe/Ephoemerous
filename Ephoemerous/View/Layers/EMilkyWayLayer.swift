import SwiftUI
import simd

// Approximate Milky Way: two soft blurred passes along the galactic plane
// (a brighter core + a wide faint halo) plus a warmer galactic-centre glow.
// Projected through the same pipeline as the sky (sidereally rotated →
// EProjection → toScreen), so it is inherently date- and location-dependent
// and stays glued to the star field at every zoom.
//
// Performance: the old version blurred 9 separate strips over 9×361 samples
// every frame (≈10 Gaussian passes/frame) — that alone pinned the CPU.
// This draws 2 blurred strokes over 64 samples each + 1 bulge, and skips
// entirely unless its projection frame matches the current app mode (so it
// never double-draws in travel).
struct EMilkyWayLayer: EGridLayer {

    let mode: EProjection.ProjectionFrame

    private let sampleSteps = 64

    func draw(in dc: inout EGraphicContext) {
        // skyLayers carries the .northSouth instance (clock); travelLayers
        // the .userLocation one (travel). Only the matching one does work.
        let isClockFrame = (mode == .northSouth)
        guard (isClockFrame && dc.state.appMode == .clock)
           || (!isClockFrame && dc.state.appMode == .travel) else { return }

        let offset = dc.state.localSiderealOffset
        let plane  = galacticPlanePath(in: dc, offset: offset)
        guard !plane.isEmpty else { return }

        // Wide faint halo, then a brighter narrower core — one blur each.
        strokeBlurred(plane, in: &dc,
                      color: Color(hue: 0.62, saturation: 0.22, brightness: 0.9),
                      opacity: 0.05, width: 90, blur: 22)
        strokeBlurred(plane, in: &dc,
                      color: Color(hue: 0.62, saturation: 0.28, brightness: 0.95),
                      opacity: 0.13, width: 34, blur: 10)

        drawGalacticCentreGlow(in: &dc, offset: offset)
    }

    // Galactic equator (b = 0) as a screen-space path, breaking at
    // projection drop-outs / back-side discontinuities.
    private func galacticPlanePath(in dc: EGraphicContext, offset: Angle) -> Path {
        let projected = EProjection.sampleCurve(steps: sampleSteps,
                                                appState: dc.state, mode: mode) { t in
            EGalacticCoords.equatorialVector(l: t * .twoPi, b: 0)
                .sidereallyRotated(by: offset)
        }
        var path = Path()
        var prev: CGPoint? = nil
        for p in projected {
            guard let p else { prev = nil; continue }
            let s = dc.toScreen(p)
            if let q = prev {
                let dx = s.x - q.x, dy = s.y - q.y
                if dx * dx + dy * dy < 80_000 { path.addLine(to: s) }
                else { path.move(to: s) }
            } else {
                path.move(to: s)
            }
            prev = s
        }
        return path
    }

    private func strokeBlurred(_ path: Path, in dc: inout EGraphicContext,
                               color: Color, opacity: Double,
                               width: Double, blur: Double) {
        var ctx = dc.ctx
        ctx.addFilter(.blur(radius: blur))
        ctx.stroke(path, with: .color(color.opacity(opacity)), lineWidth: width)
    }

    private func drawGalacticCentreGlow(in dc: inout EGraphicContext, offset: Angle) {
        let gc = EGalacticCoords.equatorialVector(l: 0, b: 0)
            .sidereallyRotated(by: offset)
        guard let proj = EProjection.project(gc, appState: dc.state, mode: mode)
        else { return }
        let p = dc.toScreen(proj)

        var bulge = dc.ctx
        bulge.addFilter(.blur(radius: 26))
        bulge.fill(
            Path(ellipseIn: CGRect(x: p.x - 26, y: p.y - 15, width: 52, height: 30)),
            with: .color(Color(hue: 0.10, saturation: 0.5, brightness: 0.9)
                .opacity(0.30))
        )
    }
}

import SwiftUI
import simd

// MARK: - SkyLabGridCanvas
// The equatorial grid as a Canvas — the cheap, many-stroke layer that
// SHOULD stay Canvas (thousands of strokes/dots are its sweet spot). It
// renders at the camera's COMMITTED transform; the shared parent
// transform in SkyLabView handles live pan / zoom, so this draw closure
// only re-runs when the committed camera actually changes (a settle, a
// date / origin move), never mid-gesture.
struct SkyLabGridCanvas: View, Equatable {
    let camera: SkyLabCamera   // Equatable synthesised → `.equatable()` skips
                               // the redraw while the camera is frozen.

    private static let parallelsDeg:  [Double] = [-60, -30, 0, 30, 60]
    private static let meridianHours: [Double] = stride(from: 0, to: 24, by: 2).map { $0 }

    var body: some View {
        Canvas { ctx, _ in
            var path = Path()

            // Parallels — constant declination, RA sweeps 0…2π.
            for decDeg in Self.parallelsDeg {
                appendCurve(to: &path) { t in
                    EPrecession.equatorialVector(ra:  .radians(t * 2 * .pi),
                                                 dec: .degrees(decDeg))
                }
            }
            // Meridians — constant RA, Dec sweeps −90°…90°.
            for h in Self.meridianHours {
                appendCurve(to: &path) { t in
                    EPrecession.equatorialVector(ra:  .radians(h / 24 * 2 * .pi),
                                                 dec: .radians((t - 0.5) * .pi))
                }
            }

            ctx.stroke(path, with: .color(.secondary.opacity(0.45)), lineWidth: 0.6)
        }
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

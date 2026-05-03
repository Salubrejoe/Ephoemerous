import SwiftUI
import simd

struct EULMilkyWayLayer: EGridLayer {

    func draw(in dc: inout EGraphicContext) {
        let size   = dc.size
        let cx     = size.width  / 2
        let cy     = size.height / 2
        let radius = min(size.width, size.height) / 2

        // Navy background disc
        let bg = Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius,
                                        width: radius * 2, height: radius * 2))
        dc.ctx.fill(bg, with: .color(Color(hue: 0.64, saturation: 0.85, brightness: 0.06)))

        let offset = dc.state.localSiderealOffset

        // Milky Way band: sample galactic parallels at several latitudes
        let latStrips: [Double] = [0, 5, -5, 10, -10, 15, -15, 20, -20]
            .map { $0 * .pi / 180.0 }

        for b in latStrips {
            let opacity = EGalacticCoords.bandOpacity(b: b)
            guard opacity > 0.01 else { continue }

            let pts = EProjection.sampleCurve(appState: dc.state, mode: .userLocation) { t in
                EGalacticCoords.equatorialVector(l: t * .twoPi, b: b)
                    .sidereallyRotated(by: offset)
            }
            let screenPts = pts.compactMap { $0 }
            guard screenPts.count > 2 else { continue }

            var path = Path()
            path.move(to: screenPts[0])
            for pt in screenPts.dropFirst() { path.addLine(to: pt) }

            var glowCtx = dc.ctx
            glowCtx.addFilter(.blur(radius: 8))
            glowCtx.stroke(
                path,
                with: .color(Color(hue: 0.62, saturation: 0.25, brightness: 0.9)
                    .opacity(opacity * 0.18)),
                lineWidth: 28
            )
        }

        // Galactic centre bulge -- warm glow at l=0, b=0
        let gcVec = EGalacticCoords.equatorialVector(l: 0, b: 0)
            .sidereallyRotated(by: offset)
        if let gcProj = EProjection.project(gcVec, appState: dc.state, mode: .userLocation) {
            let gcPt = dc.toScreen(gcProj)
            var bulgeCtx = dc.ctx
            bulgeCtx.addFilter(.blur(radius: 24))
            bulgeCtx.fill(
                Path(ellipseIn: CGRect(x: gcPt.x - 20, y: gcPt.y - 12,
                                       width: 40, height: 24)),
                with: .color(Color(hue: 0.10, saturation: 0.5, brightness: 0.9).opacity(0.35))
            )
        }
    }
}

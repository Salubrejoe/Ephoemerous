import SwiftUI
import simd

struct EULMoonLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        let siderealOffset = dc.state.localSiderealOffset
        let (vec, _, _) = EMoonPosition.vector(for: dc.state.renderedObservationDate, siderealOffset: siderealOffset)
        guard let proj = EProjection.project(vec, appState: dc.state, mode: .userLocation) else { return }
        let sc = dc.toScreen(proj)
        let pos = sc; let state = dc.state
        DispatchQueue.main.async { state.moonScreenPosition = pos }
        let r = AstroConstants.moonBaseRadius
        let disc = Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r, width: r * 2, height: r * 2))
        dc.ctx.fill(disc, with: .color(.white.opacity(0.9)))
        dc.ctx.stroke(disc, with: .color(.white.opacity(0.4)), lineWidth: 0.5)
    }
}

import SwiftUI
import simd

struct EULSunLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        let date   = dc.state.renderedObservationDate
        let lambda = ENSSunLayer.sunEclipticLongitude(for: date)
        let th = dc.state.localSiderealOffset.radians
        let (c, s) = (cos(th), sin(th))
        let eq = SIMD3<Double>.eclipticPoint(lambda: lambda)
        let Q  = SIMD3(eq.x * c - eq.y * s, eq.x * s + eq.y * c, eq.z)
        guard let proj = EProjection.project(Q, appState: dc.state, mode: .userLocation) else { return }
        let sc = dc.toScreen(proj)
        let pos = sc; let state = dc.state
        DispatchQueue.main.async { state.sunScreenPosition = pos }
        // Sun disc
        let r = AstroConstants.sunDiscDiameter / 2
        let disc = Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r, width: r * 2, height: r * 2))
        dc.ctx.fill(disc, with: .color(.yellow.opacity(0.85)))
        let ring = Path(ellipseIn: CGRect(x: sc.x - (r + 5), y: sc.y - (r + 5), width: (r + 5) * 2, height: (r + 5) * 2))
        dc.ctx.stroke(ring, with: .color(.yellow.opacity(0.5)), lineWidth: 1.0)
    }
}
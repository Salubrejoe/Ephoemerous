import SwiftUI
import simd

struct EMoonLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        let (moonVec, ra, dec) = EMoonPosition.vector(for: dc.renderedObservationDate,
                                                      siderealOffset: dc.localSiderealOffset)
guard let proj = EProjection.project(moonVec, appState: dc.state, mode: mode) else { return }
        let sc = dc.toScreen(proj)
        guard dc.onScreen(sc, margin: 40) else { return }

        let pos = sc; let state = dc.state
        DispatchQueue.main.async { state.moonScreenPosition = pos }

        let fraction = EMoonPosition.illuminatedFraction(for: dc.renderedObservationDate)
        artist.drawMoon(at: sc, fraction: fraction, showRing: mode == .northSouth, in: &dc)
    }
}

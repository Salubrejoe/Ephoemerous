import SwiftUI
import simd

struct EMoonLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        let (moonVec, ra, dec) = EMoonPosition.vector(for: dc.renderedObservationDate,
                                                      siderealOffset: dc.localSiderealOffset)
        guard let proj = EProjection.project(moonVec, viewpoint: dc.viewpoint) else { return }
        let sc = dc.toScreen(proj)
        guard dc.onScreen(sc, margin: 40) else { return }

        let pos = sc; let state = dc.state
        DispatchQueue.main.async { state.moonScreenPosition = pos }

        let fraction = EMoonPosition.illuminatedFraction(for: dc.renderedObservationDate)
        // Ring is a clock-mode decoration (the watch face's moon-phase
        // indicator). Travel mode shows just the bare disc.
        artist.drawMoon(at: sc, fraction: fraction,
                        showRing: dc.state.appMode == .clock, in: &dc)
    }
}

import SwiftUI
import simd

struct EPlanetsLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showPlanets else { return }
        let pairs = EPlanetPosition.allVectors(for: dc.renderedObservationDate,
                                               siderealOffset: dc.localSiderealOffset)
        for (planet, vec, _, _) in pairs {
            guard let proj = EProjection.project(vec, viewpoint: dc.viewpoint, mode: mode) else { continue }
            let sc = dc.toScreen(proj)
            guard dc.onScreen(sc, margin: 30) else { continue }
            artist.drawPlanet(planet, at: sc, showLabel: dc.state.scale >= 90, in: &dc)
        }
    }
}

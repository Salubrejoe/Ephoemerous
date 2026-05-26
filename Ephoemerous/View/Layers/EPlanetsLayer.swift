import SwiftUI
import simd

struct EPlanetsLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showPlanets else { return }
        let pairs = EPlanetPosition.allVectors(for: dc.renderedObservationDate,
                                               siderealOffset: dc.localSiderealOffset)
        for (planet, vec, _, _) in pairs {
            guard let proj = EProjection.project(vec, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)
            guard dc.onScreen(sc, margin: 30) else { continue }
            artist.drawPOILabel(
                at:       sc,
                glyph:    .unicode(artist.planetGlyph(planet)),
                text:     planet.name,
                category: .planet(planet),
                in:       &dc
            )
        }
    }
}

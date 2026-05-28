import SwiftUI
import simd

// MARK: - EPlanetsLayer
// Solar-system POI badges for the seven planets. Same `drawPOILabel`
// pipeline as the sun and moon — heptagon (8-corner squircle) with
// the planet's astronomical Unicode glyph inside.
//
// Side effect: publishes each planet's screen position to
// `state.planetPositions` so the tap-overlay can hit-test them and
// `state.focus(on: .planet(...))` can pan-to-centre. Mirrors the
// per-frame snapshot pattern used by stars / constellations.
struct EPlanetsLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        let pairs = EPlanetPosition.allVectors(for: dc.renderedObservationDate,
                                               siderealOffset: dc.localSiderealOffset)
        var positions: [String: CGPoint] = [:]
        positions.reserveCapacity(pairs.count)

        for (planet, vec, _, _) in pairs {
            guard let proj = EProjection.project(vec, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)
            positions[planet.name] = sc
            guard dc.onScreen(sc, margin: 30) else { continue }
            // `drawDot: true` keeps a tinted dot on-canvas below the
            // badge-in threshold, so a planet doesn't disappear when
            // the user zooms out.
            artist.drawPOILabel(
                at:       sc,
                glyph:    .unicode(artist.planetGlyph(planet)),
                text:     planet.name,
                category: .planet(planet),
                drawDot:  true,
                in:       &dc
            )
        }

        let snapshot = positions
        let stateRef = dc.state
        // Equality-guard — see SunLayer for the rationale. Comparing
        // a 7-key dict is cheap; firing @Observable invalidation 119×
        // per second when nothing changed is not.
        DispatchQueue.main.async {
            if stateRef.planetPositions != snapshot {
                stateRef.planetPositions = snapshot
            }
        }
    }
}

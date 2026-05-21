import SwiftUI
import simd

// Constellation names rendered at the vector-centroid of each
// constellation's figure-stars. Anchors are precomputed once at
// load-time and live on `ConstellationLines.labelAnchors`.
struct ConstellationNamesLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showConstellationNames else { return }

        for (cons, anchor) in ConstellationLines.shared.labelAnchors {
            let (pRA, pDec) = EPrecession.precess(ra: anchor.ra, dec: anchor.dec,
                                                  to: dc.state.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.state.localSiderealOffset)
            guard let proj = EProjection.project(Q, appState: dc.state, mode: mode) else { continue }
            let sc = dc.toScreen(proj)
            artist.drawConstellationLabel(cons, at: sc, in: &dc)
        }
    }
}

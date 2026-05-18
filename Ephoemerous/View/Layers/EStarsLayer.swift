import SwiftUI

struct EStarsLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showStars else { return }
        
        for star in starsToShow(in: dc) {
            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                                  to: dc.state.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.state.localSiderealOffset)
            guard let proj = EProjection.project(Q, appState: dc.state, mode: mode) else { continue }
            let sc = dc.toScreen(proj)
            guard artist.starPointFallsWithinMarigin(sc, in: dc) else { continue }
            artist.drawStar(star, at: sc, in: &dc)
        }
    }
    
    func starsToShow(in dc: EGraphicContext) -> [EStar] {
        if dc.state.appMode != .travel && dc.state.showHorizon {
            dc.state.stars
        } else {
            dc.state.travelStars
        }
    }
}

import SwiftUI

struct StarsLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showStars else { return }

        // Clock mode → cull to the chrome disc (sub-pixel hypot² check
        // against r²). Travel mode → fall back to the canvas-margin
        // rectangle since there's no chrome.
        let inClock     = dc.state.appMode == .clock
        let chrome      = artist.chromeBounds(in: dc)
        let chromeR2    = chrome.radius * chrome.radius

        for star in starsToShow(in: dc) {
            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint, mode: mode) else { continue }
            let sc = dc.toScreen(proj)
            if inClock {
                let dx = sc.x - chrome.centre.x
                let dy = sc.y - chrome.centre.y
                guard dx * dx + dy * dy < chromeR2 else { continue }
            } else {
                guard artist.starPointFallsWithinMarigin(sc, in: dc) else { continue }
            }
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

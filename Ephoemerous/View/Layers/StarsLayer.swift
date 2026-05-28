import SwiftUI

struct StarsLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        // Clock mode → cull to the chrome disc (sub-pixel hypot² check
        // against r²). Travel mode → fall back to the canvas-margin
        // rectangle since there's no chrome.
        let inClock     = dc.state.appMode == .clock
        let chrome      = artist.chromeBounds(in: dc)
        let chromeR2    = chrome.radius * chrome.radius

        // Skip stars that an upper layer will paint over on the same
        // frame:
        //   • Favourites — FavouritesLayer always draws them as a
        //     heart (low zoom) or badge+heart (high zoom). The
        //     generic star fill below would just disappear under
        //     either treatment.
        //   • Proper-named stars at zoom levels where NamedStarsLayer
        //     starts revealing them — its dot/badge replaces the
        //     generic star glyph entirely. Below the threshold
        //     NamedStarsLayer is silent and StarsLayer still needs to
        //     paint these (otherwise named stars would vanish at low
        //     zoom).
        let favouriteNames = Set(dc.state.favouriteStars.map(\.name))
        let hideNamed      = dc.renderedScale >= artist.namedStarDotIn

        for star in starsToShow(in: dc) {
            if favouriteNames.contains(star.name) { continue }
            if hideNamed && NamedStarsLayer.candidateNames.contains(star.name) { continue }

            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
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
        // Clock mode: horizon-filtered list so the watch face only
        // shows visible-sky stars. Travel mode: full sphere.
        dc.state.appMode == .travel ? dc.state.travelStars : dc.state.stars
    }
}

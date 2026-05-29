import SwiftUI

struct StarsLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
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

        for star in dc.state.stars {
            if favouriteNames.contains(star.name) { continue }
            if hideNamed && NamedStarsLayer.candidateNames.contains(star.name) { continue }

            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)
            // Single screen-margin cull — the old chrome-disc cull is
            // gone along with the clock-mode disc concept.
            guard artist.starPointFallsWithinMarigin(sc, in: dc) else { continue }
            artist.drawStar(star, at: sc, in: &dc)
        }
    }
}

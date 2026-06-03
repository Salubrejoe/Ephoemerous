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

        // Per-frame visibility gate: one dot product against the star's
        // cached constant vector rejects everything outside the visible
        // cone BEFORE the expensive precess → project → toScreen chain.
        // At deep zoom the cone is tiny, so ~all stars are rejected for
        // the cost of a dot — that's what makes zoomed-in cheap.
        let cull = dc.makeStarCull()

        // Zoom-driven visible set: a magnitude-sorted prefix capped by
        // zoom (fainter stars appear as you pinch in). Capped at
        // `magnitudeScale` — the pan DESTINATION while a transition runs —
        // so the star count is fixed for the whole pan instead of growing
        // frame-by-frame (the star-pan stutter). See `EAppState`.
        for star in dc.state.visibleStars(forScale: dc.state.magnitudeScale) {
            if favouriteNames.contains(star.name) { continue }
            if hideNamed && NamedStarsLayer.candidateNames.contains(star.name) { continue }

            // Cheap angular cull on the cached vector — skips the trig
            // chain below for off-screen stars.
            guard cull.keeps(star.equatorialVector) else { continue }

            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)
            // Final exact screen-margin cull (the angular cull is
            // conservative; this trims the corners precisely).
            guard artist.starPointFallsWithinMarigin(sc, in: dc) else { continue }
            artist.drawStar(star, at: sc, in: &dc)
        }
    }
}

import SwiftUI

// MARK: - StarsLayer
// The generic star field. Two render paths share one visual result:
//
//   • Slow path (geometry changing — zoom / rotate / date / location):
//     the full pipeline — angular cull → precess → project → toScreen →
//     margin → draw. Re-projects every frame, which is correct while the
//     sky is genuinely moving.
//
//   • Fast path (geometry STABLE for ≥2 frames — a pan, or a settled
//     view): a pan only changes `offset`, which `toScreen` adds in screen
//     space AFTER projection. So the projection is invariant and a pan is
//     a rigid translation. We cache each star's OFFSET-FREE base point and
//     each frame just add the live offset + a screen-margin cull. No trig.
//
// "Geometry stable" = this frame's `StarProjectionKey` equals the previous
// frame's (the key excludes offset). The cache builds on the first stable
// frame — which, after any move settles, is the idle paint — so a pan
// begins already cached, with no first-frame projection spike.
struct StarsLayer: EGridLayer {

    func draw(in dc: inout EGraphicContext) {
        // Skipped sets (stable during a pan): favourites are painted by
        // FavouritesLayer; proper-named stars are taken over by
        // NamedStarsLayer once zoomed in past `namedStarDotIn`.
        let favouriteNames = Set(dc.state.favouriteStars.map(\.name))
        let hideNamed      = dc.renderedScale >= artist.namedStarDotIn

        let key = StarProjectionKey(
            scale:    dc.renderedScale,
            rotation: dc.canvasRotation.radians,
            date:     dc.renderedObservationDate,
            lat:      dc.state.origin.latitude.degrees,
            lon:      dc.state.origin.longitude.degrees,
            width:    dc.size.width,
            height:   dc.size.height,
            favourites: dc.state.favourites.count
        )
        let geometryStable = dc.state._lastStarKey == key
        dc.state._lastStarKey = key

        // Capped per zoom; constant for the whole pan (frozen at the
        // transition target while a camera move runs — see `magnitudeScale`).
        let stars = dc.state.visibleStars(forScale: dc.state.magnitudeScale)

        if geometryStable {
            if dc.state._starBaseKey != key || dc.state._starBasePoints.count != stars.count {
                buildBaseCache(stars, favouriteNames: favouriteNames,
                               hideNamed: hideNamed, key: key, in: &dc)
            }
            drawFromCache(stars, in: &dc)
        } else {
            drawFullPipeline(stars, favouriteNames: favouriteNames,
                             hideNamed: hideNamed, in: &dc)
        }
    }

    // MARK: Fast path

    /// Project the visible set once into offset-free base points, aligned
    /// 1:1 with `stars`. Skipped stars (favourite / hidden-named) and
    /// no-projection stars get a NaN sentinel so the draw loop can skip
    /// them without any per-frame set lookups. No angular cull here — a
    /// pan can scroll any of them on-screen, so we keep the whole set and
    /// rect-cull per frame in `drawFromCache`.
    private func buildBaseCache(_ stars: ArraySlice<EStar>,
                                favouriteNames: Set<String>,
                                hideNamed: Bool,
                                key: StarProjectionKey,
                                in dc: inout EGraphicContext) {
        let nan = CGPoint(x: CGFloat.nan, y: CGFloat.nan)
        var bases = [CGPoint](repeating: nan, count: stars.count)
        let ox = dc.renderedOffset.y
        let oy = dc.renderedOffset.x
        for (i, star) in stars.enumerated() {
            if favouriteNames.contains(star.name) { continue }
            if hideNamed && NamedStarsLayer.candidateNames.contains(star.name) { continue }
            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension,
                                                  dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)
            // Strip the offset that toScreen baked in → offset-free base.
            bases[i] = CGPoint(x: sc.x - ox, y: sc.y - oy)
        }
        dc.state._starBasePoints = bases
        dc.state._starBaseKey    = key
    }

    private func drawFromCache(_ stars: ArraySlice<EStar>, in dc: inout EGraphicContext) {
        let bases = dc.state._starBasePoints
        let ox = dc.renderedOffset.y
        let oy = dc.renderedOffset.x
        for (i, star) in stars.enumerated() {
            let b = bases[i]
            if b.x.isNaN { continue }
            let sc = CGPoint(x: b.x + ox, y: b.y + oy)
            guard artist.starPointFallsWithinMarigin(sc, in: dc) else { continue }
            artist.drawStar(star, at: sc, in: &dc)
        }
    }

    // MARK: Slow path (unchanged pipeline)

    private func drawFullPipeline(_ stars: ArraySlice<EStar>,
                                  favouriteNames: Set<String>,
                                  hideNamed: Bool,
                                  in dc: inout EGraphicContext) {
        let cull = dc.makeStarCull()
        for star in stars {
            if favouriteNames.contains(star.name) { continue }
            if hideNamed && NamedStarsLayer.candidateNames.contains(star.name) { continue }
            guard cull.keeps(star.equatorialVector) else { continue }
            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension,
                                                  dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)
            guard artist.starPointFallsWithinMarigin(sc, in: dc) else { continue }
            artist.drawStar(star, at: sc, in: &dc)
        }
    }
}

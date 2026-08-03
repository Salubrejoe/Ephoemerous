import SwiftUI

// MARK: - StarsLayer
// The generic star field. Two render paths share one visual result:
//
//   • Slow path (date / location CHANGING — a date scrub or an origin
//     slerp): the full pipeline — angular cull → precess → project →
//     toScreen → margin → draw. The projection genuinely moves frame to
//     frame, so we re-project (rect-culled) every frame.
//
//   • Fast path (date + origin STABLE for ≥2 frames — i.e. ANY of pan,
//     pinch, rotate, or a settled view): a star's projection-unit point
//     depends ONLY on (date, origin). `canvasRotation`, `scale` and
//     `offset` are all applied later, inside `toScreen`. So while date +
//     origin hold, the projection is invariant and every gesture frame
//     just re-runs the cheap toScreen on the cached projections — no
//     precess / project / cull trig for ~2k stars.
//
// The cache (`_starProjPoints`) is aligned 1:1 with `sortedStars` and
// covers the whole catalogue, so pinch-in can reveal fainter stars (a
// longer prefix) without a rebuild. It's built on the first stable frame
// — which, after any date/location move settles, is the idle paint — so
// every gesture begins already cached, with no first-frame spike.
//
// Skips (favourite / proper-named) are applied PER FRAME, not baked into
// the cache: `hideNamed` flips with zoom mid-pinch, and a favourite can
// be toggled mid-view — both must stay live.
struct StarsLayer: EGridLayer {

    func draw(in dc: inout EGraphicContext) {
        let favouriteNames = Set(dc.state.favouriteStars.map(\.name))
        let hideNamed      = dc.renderedScale >= artist.namedStarDotIn
        // Over-zoom name reveal: 0 at normal zoom (no label work), ramps in
        // as the scale pushes past the ceiling. Drawn per on-screen star.
        let overZoom       = artist.overZoomLabelOpacity(scale: dc.renderedScale)

        let key = StarProjectionKey(
            date: dc.renderedObservationDate,
            lat:  dc.state.origin.latitude.degrees,
            lon:  dc.state.origin.longitude.degrees
        )
        let stable = dc.state._lastStarKey == key
        dc.state._lastStarKey = key

        // Visible prefix (capped per zoom). Because it's a true prefix of
        // `sortedStars`, prefix index i == sortedStars index i == cache
        // index i — so the cache stays aligned even as the cap grows.
        let stars = dc.state.visibleStars(forScale: dc.state.magnitudeScale)

        if stable {
            let all = dc.state.sortedStars
            if dc.state._starProjKey != key
                || dc.state._starProjPoints.count != all.count {
                buildProjCache(all, key: key, in: &dc)
            }
            drawFromCache(stars, favouriteNames: favouriteNames,
                          hideNamed: hideNamed, overZoom: overZoom, in: &dc)
        } else {
            drawFullPipeline(stars, favouriteNames: favouriteNames,
                             hideNamed: hideNamed, overZoom: overZoom, in: &dc)
        }
    }

    // MARK: Fast path

    /// Project the WHOLE catalogue once into projection-unit points,
    /// aligned 1:1 with `sortedStars` (NaN sentinel where a star doesn't
    /// project). No cull and no favourite/named skips here — those are
    /// zoom/selection dependent and applied per frame in `drawFromCache`.
    private func buildProjCache(_ all: [EStar],
                                key: StarProjectionKey,
                                in dc: inout EGraphicContext) {
        let nan = CGPoint(x: CGFloat.nan, y: CGFloat.nan)
        var projs = [CGPoint](repeating: nan, count: all.count)
        for (i, star) in all.enumerated() {
            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension,
                                                  dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            projs[i] = proj
        }
        dc.state._starProjPoints = projs
        dc.state._starProjKey    = key
    }

    /// Per gesture frame: cached projection → live `toScreen` (applies the
    /// current rotation / scale / offset) → margin cull → draw. The only
    /// trig is `toScreen`'s single 2D rotation, shared by every star.
    private func drawFromCache(_ stars: ArraySlice<EStar>,
                               favouriteNames: Set<String>,
                               hideNamed: Bool,
                               overZoom: Double,
                               in dc: inout EGraphicContext) {
        let projs = dc.state._starProjPoints
        let skipFavourites = !favouriteNames.isEmpty
        for (i, star) in stars.enumerated() {
            let p = projs[i]
            if p.x.isNaN { continue }
            if skipFavourites && favouriteNames.contains(star.name) { continue }
            if hideNamed && NamedStarsLayer.candidateNames.contains(star.name) { continue }
            let sc = dc.toScreen(p)
            guard artist.starPointFallsWithinMarigin(sc, in: dc) else { continue }
            artist.drawStar(star, at: sc, in: &dc)
            if overZoom > 0 {
                artist.drawStarNameLabel(star, at: sc, opacity: overZoom, in: &dc)
            }
        }
    }

    // MARK: Slow path (unchanged pipeline)

    private func drawFullPipeline(_ stars: ArraySlice<EStar>,
                                  favouriteNames: Set<String>,
                                  hideNamed: Bool,
                                  overZoom: Double,
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
            if overZoom > 0 {
                artist.drawStarNameLabel(star, at: sc, opacity: overZoom, in: &dc)
            }
        }
    }
}

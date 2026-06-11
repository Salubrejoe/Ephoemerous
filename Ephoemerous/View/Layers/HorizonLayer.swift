import SwiftUI
import simd
import LoreKit

struct HorizonLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        // Resolve the horizon wash to concrete RGBA once — used for every
        // twilight band plus the rim, so this avoids re-resolving the
        // asset on the main thread per fill.
        let fill = dc.resolve(artist.horizonFillColor)

        // Projection cache — same invariant as StarsLayer: the sampled,
        // bumped rings (3 twilight bands + the rim, 361 points each, plus
        // the squircle bump per point) are fixed in projection space while
        // (date, origin) hold, so gesture frames only pay the `toScreen`
        // inside `fillOutsideCurve` on cached points.
        let key = StarProjectionKey(
            date: dc.renderedObservationDate,
            lat:  dc.state.origin.latitude.degrees,
            lon:  dc.state.origin.longitude.degrees
        )
        if dc.state._horizonProjKey != key {
            rebuildCache(in: dc)
            dc.state._horizonProjKey = key
        }

        // Twilight bands: small circles at constant altitude just
        // above / below the horizon (the values in `Angle.sunsets`
        // are altitudes, not declinations — e.g. `.civil` = -6° below
        // the horizon, `.astronomical` = -18°). Filled with reduced
        // opacity so they stack into a smooth twilight gradient.
        var bands = dc
        for pts in dc.state._twilightBandPts {
            bands.fillOutsideCurve(pts, color: fill.opacity(0.2))
        }

        // Fill *outside* the rim, leaving the visible-sky disc bare.
        // The below-horizon region (everywhere outside the alt = 0
        // circle) reads as tinted, so the rim becomes a window onto
        // the sky rather than a small wash sitting on top of it.
        guard !dc.state._horizonRimPts.isEmpty else { return }
        var rim = dc
        rim.fillOutsideCurve(dc.state._horizonRimPts, color: fill)
    }

    /// Full sampling pass, run only when the cache key falls stale (date
    /// scrub / origin move) — not per gesture frame.
    ///
    /// Each ring is a deformable squircle: every projection sample is
    /// pushed radially outward from the curve's centroid by
    /// `Squircle.lameRadius(θ)` (`bumpedHorizonRim`). This rides whatever
    /// shape the projection produces — true circle in pure stereographic,
    /// or a deformed conic when the origin and plane fall out of sync —
    /// and lays 24 evenly-spaced bumps over it. All in projection units;
    /// the screen mapping happens at draw time.
    ///
    /// The rim itself is the horizon great circle: alt = 0, the locus
    /// perpendicular to the observer's zenith. It projects to a true
    /// circle of radius 2 (projection units) centred on screen — the
    /// visible-sky boundary in the astrolabe sense. Stars / sun / moon
    /// inside this rim are above the horizon right now; outside are below.
    private func rebuildCache(in dc: EGraphicContext) {
        var bandPts: [[CGPoint?]] = []
        for alt in Angle.sunsets where alt != .horizon {
            let pts = EProjection.sampleCurve(viewpoint: dc.viewpoint) { t in
                dc.viewpoint.skyPoint(altitude: alt, at: t)
            }.compactMap { $0 }
            guard pts.count >= 8 else { continue }
            bandPts.append(artist.bumpedHorizonRim(pts))
        }
        dc.state._twilightBandPts = bandPts

        let pts = EProjection.sampleCurve(viewpoint: dc.viewpoint) { t in
            dc.viewpoint.skyPoint(altitude: .horizon, at: t)
        }.compactMap { $0 }
        dc.state._horizonRimPts = pts.count >= 8 ? artist.bumpedHorizonRim(pts) : []
    }
}

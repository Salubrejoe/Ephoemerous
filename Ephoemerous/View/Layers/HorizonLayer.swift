import SwiftUI
import simd
import LoreKit

struct HorizonLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        // Resolve the horizon wash to concrete RGBA once — used for every
        // twilight band plus the rim, so this avoids re-resolving the
        // asset on the main thread per fill.
        let fill = dc.resolve(artist.horizonFillColor)
        var bands = dc
        // Twilight bands: small circles at constant altitude just
        // above / below the horizon (the values in `Angle.sunsets`
        // are altitudes, not declinations — e.g. `.civil` = -6° below
        // the horizon, `.astronomical` = -18°). Filled with reduced
        // opacity so they stack into a smooth twilight gradient.
        for alt in Angle.sunsets where alt != .horizon {
            let pts = EProjection.sampleCurve(viewpoint: bands.viewpoint) { t in
                bands.viewpoint.skyPoint(altitude: alt, at: t)
            }.compactMap { $0 }
            guard pts.count >= 8 else { continue }
//            bands.strokeCurve(artist.bumpedHorizonRim(pts),
//            bands.strokeCurve(pts,
//                              color: artist.twilightBandColor,
//                              width: 12 / abs(alt.degrees))
            bands.fillOutsideCurve(artist.bumpedHorizonRim(pts),
//            bands.fillOutsideCurve(pts,
                                   color: fill.opacity(0.2))
        }

        // Horizon great circle as a deformable squircle: each projection
        // sample is pushed radially outward from the curve's centroid by
        // `Squircle.lameRadius(θ)`. This rides whatever shape the
        // projection produces — true circle in pure stereographic, or a
        // deformed conic when the origin and plane fall out of sync —
        // and lays 24 evenly-spaced bumps over it. Routed through
        // `strokeCurve` so the projection→screen mapping is handled.
        // Horizon great circle: alt = 0, i.e. the locus perpendicular
        // to the observer's zenith. Projects to a true circle of
        // radius 2 (projection units) centred on screen — the
        // visible-sky boundary in the astrolabe sense. Stars / sun /
        // moon inside this rim are above the horizon right now;
        // outside are below.
        var rim = dc
        let pts = EProjection.sampleCurve(viewpoint: rim.viewpoint) { t in
            rim.viewpoint.skyPoint(altitude: .horizon, at: t)
        }.compactMap { $0 }
        guard pts.count >= 8 else { return }
        // Fill *outside* the rim, leaving the visible-sky disc bare.
        // The below-horizon region (everywhere outside the alt = 0
        // circle) reads as tinted, so the rim becomes a window onto
        // the sky rather than a small wash sitting on top of it.
//        rim.ctx.addFilter(.shadow(color: .primary, radius: 4))
//        rim.fillOutsideCurve(pts,
        rim.fillOutsideCurve(artist.bumpedHorizonRim(pts),
                             color: fill)
    }
}

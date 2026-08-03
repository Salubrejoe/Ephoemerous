

import SwiftUI
import simd
import LoreKit


struct EarthGridLayer: EGridLayer {
    
    func draw(in dc: inout EGraphicContext) {
        // Resolve the grid colour to concrete RGBA once for the whole
        // frame — drawn ~31× (meridians + parallels), so without this each
        // stroke would re-resolve the "grid" asset on the main thread.
        let gridColor = dc.resolve(artist.gridColor)

        // Projection cache — same invariant as StarsLayer: the 31 sampled
        // curves (12 meridians + 19 parallels × 361 points ≈ 11k full
        // projections) depend only on (date, origin). While those hold —
        // i.e. every frame of a pan / pinch / rotate — `strokeCurve`
        // re-runs only the cheap `toScreen` on the cached points.
        let key = StarProjectionKey(
            date: dc.renderedObservationDate,
            lat:  dc.state.origin.latitude.degrees,
            lon:  dc.state.origin.longitude.degrees
        )
        if dc.state._gridProjKey != key {
            dc.state._gridCurves  = sampleAllCurves(in: dc)
            dc.state._gridProjKey = key
        }

        var local = dc
        for pts in dc.state._gridCurves {
            local.strokeCurve(pts, color: gridColor, width: artist.gridWidth)
        }
        drawPoleLabels(in: &dc)
    }

    /// Full (date, origin)-dependent sampling pass: every meridian and
    /// parallel, in projection units. Runs only when the cache key falls
    /// stale (a date scrub or an origin move), not per gesture frame.
    private func sampleAllCurves(in dc: EGraphicContext) -> [[CGPoint?]] {
        var curves: [[CGPoint?]] = []
        curves.reserveCapacity(12 + Angle.parallels.count)

        for h in stride(from: 0.0, to: 12.0, by: 1.0) {
            let ra = h / 24.0 * Double.twoPi
            curves.append(EProjection.sampleCurve(viewpoint: dc.viewpoint) { t in
                EPrecession.equatorialVector(ra: .radians(ra),
                                             dec: .radians((t - 0.5) * 2 * Double.pi))
                    .sidereallyRotated(by: dc.localSiderealOffset)
            })
        }
        for decl in Angle.parallels {
            curves.append(EProjection.sampleCurve(viewpoint: dc.viewpoint) { t in
                EPrecession.equatorialVector(ra: .radians(t * .twoPi), dec: decl)
                    .sidereallyRotated(by: dc.localSiderealOffset)
            })
        }
        return curves
    }

    // MARK: - Celestial-pole labels (N / S)
    //
    // The meridian fan converges at dec = ±89.99°; "N" / "S" pin to those
    // convergence points. The poles are invariant under sidereal rotation
    // about z, so the rotation is a no-op for them — we apply it anyway
    // for symmetry with the rest of the grid math. In clock mode (observer
    // at NP) the celestial north pole projects to the chrome centre, so
    // "N" lands dead-centre; the south pole still projects to a finite
    // (often off-canvas) point and is culled by `onScreen`.
    func drawPoleLabels(in dc: inout EGraphicContext) {
        let poles: [(dec: Angle, text: String)] = [
            (.degrees( 89.99), "N"),
            (.degrees(-89.99), "S"),
        ]
        for (dec, text) in poles {
            guard let sc = projectedScreenPoint(ra: .zero, dec: dec, in: dc),
                  dc.onScreen(sc, margin: 12)
            else { continue }
            drawGridLabel(text, at: sc, weight: .semibold, in: &dc)
        }
    }

    /// Sidereally-rotated equatorial → screen projection. Used by the
    /// pole labels to place "N" / "S" at the meridian-fan convergence.
    private func projectedScreenPoint(ra:  Angle,
                                      dec: Angle,
                                      in dc: EGraphicContext) -> CGPoint? {
        let q = EPrecession
            .equatorialVector(ra: ra, dec: dec)
            .sidereallyRotated(by: dc.localSiderealOffset)
        guard let p = EProjection.project(q, viewpoint: dc.viewpoint) else { return nil }
        return dc.toScreen(p)
    }

    /// Tiny grid-voice label (pole "N"/"S", RA hour numerals). Moved here
    /// from `EArtist+Grid` so the drawing lives with the layer; the
    /// `gridColor` / `gridWidth` tint constants stay on EArtist — SkyLab
    /// reads them too.
    private func drawGridLabel(_ text: String,
                               at sc: CGPoint,
                               weight: Font.Weight = .regular,
                               in dc: inout EGraphicContext) {
        dc.ctx.draw(
            Text(text)
                .font(.footnote.weight(weight))
                .foregroundStyle(dc.resolve(artist.gridColor)),
            at:     sc,
            anchor: .center
        )
    }
}



import SwiftUI
import simd
import LoreKit


struct EarthGridLayer: EGridLayer {
    
    func draw(in dc: inout EGraphicContext) {
        // The old clock-mode clip-to-disc lived here but every clip
        // line had already been commented out — the grid was rendering
        // free-form regardless. Now that appMode is gone, the local-
        // copy / clip dance has nothing left to do; pass `dc` straight
        // through.
        // Resolve the grid colour to concrete RGBA once for the whole
        // frame — drawn ~24× (meridians + parallels), so without this each
        // stroke would re-resolve the "grid" asset on the main thread.
        let gridColor = dc.resolve(artist.gridColor)
        drawMeridians(in:   &dc, color: gridColor)
        drawParallels(in:   &dc, color: gridColor)
        drawPoleLabels(in:  &dc)
    }

    func drawParallels(in dc: inout EGraphicContext, color: Color) {
//        guard dc.state.showHorizon else { return }

        for decl in Angle.parallels {
            let pts = EProjection.sampleCurve(viewpoint: dc.viewpoint) { t in
                EPrecession.equatorialVector(ra: .radians(t * .twoPi), dec: decl)
                    .sidereallyRotated(by: dc.localSiderealOffset)
            }

            // MARK: - DRAW
            var local = dc
            local.strokeCurve(
                pts,
                color: color,
                width: artist.gridWidth
            )
        }
    }

    func drawMeridians(in dc: inout EGraphicContext, color: Color) {
//        let show = mode == .northSouth ? dc.state.showNSMeridians : dc.state.showULMeridians
//        guard show else { return }

        for h in stride(from: 0.0, to: 12.0, by: 1.0) {
            let ra  = h / 24.0 * Double.twoPi
            let pts = EProjection.sampleCurve(viewpoint: dc.viewpoint) { t in
                EPrecession.equatorialVector(ra: .radians(ra),
                                             dec: .radians((t - 0.5) * 2*Double.pi))
                .sidereallyRotated(by: dc.localSiderealOffset)
            }
            // MARK: - DRAW
            var local = dc
            local.strokeCurve(
                pts,
                color: color,
                width: artist.gridWidth
            )
        }
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
            artist.drawGridLabel(text, at: sc, weight: .semibold, in: &dc)
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
}

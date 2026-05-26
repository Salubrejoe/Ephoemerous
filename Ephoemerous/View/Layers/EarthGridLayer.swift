

import SwiftUI
import simd
import LoreKit


struct EarthGridLayer: EGridLayer {
    let artist = EArtist.shared

    
    func draw(in dc: inout EGraphicContext) {

        // In clock mode the grid is confined to the watch disc. Clip a
        // local copy of the context — every layer shares the same
        // `inout dc`, so clipping `dc` directly would leak the region
        // into the horizon / stars / chrome drawn after this layer.
        var clipped = dc
        if dc.state.appMode == .clock {
//            clipped.ctx.clip(to: artist.chromePath(in: dc))
        }
        drawMeridians(in:   &clipped)
        drawParallels(in:   &clipped)
        drawPoleLabels(in:  &clipped)
        drawHourLabels(in:  &clipped)
    }
    
    func drawParallels(in dc: inout EGraphicContext) {
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
                color: artist.gridColor,
                width: artist.gridWidth
            )
        }
    }

    func drawMeridians(in dc: inout EGraphicContext) {
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
                color: artist.gridColor,
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
            let q = EPrecession
                .equatorialVector(ra: .zero, dec: dec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let p = EProjection.project(q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(p)
            guard dc.onScreen(sc, margin: 12) else { continue }
            dc.ctx.draw(
                Text(text)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(artist.gridColor),
                at:     sc,
                anchor: .center
            )
        }
    }

    // MARK: - RA hour numerals (0h / 6h / 12h / 18h)
    //
    // Dropped onto the celestial equator (dec = 0) so they ride the
    // dec=0 parallel as the sky rotates sidereally. Only the four
    // principal hours to keep the grid uncluttered. Any hour whose
    // projection lands off-canvas is culled.
    func drawHourLabels(in dc: inout EGraphicContext) {
        for h in [0.0, 6.0, 12.0, 18.0] {
            let ra = Angle.radians(h / 24.0 * Double.twoPi)
            let q  = EPrecession
                .equatorialVector(ra: ra, dec: .zero)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let p = EProjection.project(q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(p)
            guard dc.onScreen(sc, margin: 12) else { continue }
            dc.ctx.draw(
                Text("\(Int(h))h")
                    .font(.footnote)
                    .foregroundStyle(artist.gridColor),
                at:     sc,
                anchor: .center
            )
        }
    }
}

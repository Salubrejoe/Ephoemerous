

import SwiftUI
import simd


struct EarthGridLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame
 
    
    func draw(in dc: inout EGraphicContext) {
        var blur = dc.ctx
        blur.addFilter(.blur(radius: 4))

        // In clock mode the grid is confined to the watch disc. Clip a
        // local copy of the context — every layer shares the same
        // `inout dc`, so clipping `dc` directly would leak the region
        // into the horizon / stars / chrome drawn after this layer.
        var clipped = dc
        if dc.state.appMode == .clock {
            clipped.ctx.clip(to: artist.chromePath(in: dc))
        }
        drawMeridians(in: &clipped)
        drawParallels(in: &clipped)
    }
    
    func drawParallels(in dc: inout EGraphicContext) {
//        guard dc.state.showHorizon else { return }

        for decl in Angle.parallels {
            let pts = EProjection.sampleCurve(
                appState:           dc.state,
                mode:               .userLocation,
                negateUserLocation: true
            ) { t in
                EPrecession.equatorialVector(ra: .radians(t * .twoPi), dec: decl)
                    .sidereallyRotated(by: dc.state.localSiderealOffset)
            }

            // MARK: - DRAW
            var local = dc
            local.ctx.addFilter(.brightness(artist.gridBrightness))
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
            let pts = EProjection.sampleCurve(
                appState:           dc.state,
                mode:               mode,
                negateUserLocation: true
            ) { t in
                EPrecession.equatorialVector(ra: .radians(ra),
                                             dec: .radians((t - 0.5) * 2*Double.pi))
                .sidereallyRotated(by: dc.state.localSiderealOffset)
            }
            // MARK: - DRAW
            var local = dc
            local.ctx.addFilter(.brightness(artist.gridBrightness))
            local.strokeCurve(
                pts,
                color: artist.gridColor,
                width: artist.gridWidth
            )
        }
    }
}

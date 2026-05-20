

import SwiftUI
import simd


struct EarthGridLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame
    
    private var modeColor: Color {
        .quaternaryLabel
    }
    
    private func width(atParallel parallel: Angle) -> Double {
//        (1/abs(parallel.degrees)) * 4
        0.15
    }
    
    private func width(atMeridian meridian: Angle) -> Double {
        0.15
//        if meridian == .piHalf || meridian == .zero { 1 }
//        else { 0.5 }
    }
    
    func draw(in dc: inout EGraphicContext) {
        var blur = dc.ctx
        blur.addFilter(.blur(radius: 4))
        drawMeridians(in: &dc)
        drawParallels(in: &dc)
    }
    
    func drawParallels(in dc: inout EGraphicContext) {
//        guard dc.state.showHorizon else { return }
        
        for decl in Angle.parallels {
            let pts = EProjection.sampleCurve(appState: dc.state, mode: .userLocation) { t in
                EPrecession.equatorialVector(ra: .radians(t * .twoPi), dec: decl)
                    .sidereallyRotated(by: dc.state.localSiderealOffset)
            }
            
            // MARK: - DRAW
            dc.strokeCurve(
                pts,
                color: modeColor,
                width: width(atParallel: decl)
            )
        }
    }
    
    func drawMeridians(in dc: inout EGraphicContext) {
//        let show = mode == .northSouth ? dc.state.showNSMeridians : dc.state.showULMeridians
//        guard show else { return }
        
        for h in stride(from: 0.0, to: 12.0, by: 1.0) {
            let ra  = h / 24.0 * Double.twoPi
            let pts = EProjection.sampleCurve(appState: dc.state, mode: mode) { t in
                EPrecession.equatorialVector(ra: .radians(ra),
                                             dec: .radians((t - 0.5) * 2*Double.pi))
                .sidereallyRotated(by: dc.state.localSiderealOffset)
            }
            // MARK: - DRAW
            dc.strokeCurve(
                pts,
                color: modeColor,
                width: width(atMeridian: .radians(ra))
            )
        }
    }
}

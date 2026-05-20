import SwiftUI
import simd


struct EULHorizonLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showHorizon else { return }

        let horizon = EProjection.sampleCurve(appState: dc.state, mode: .userLocation) { t in
            EPrecession.equatorialVector(ra: .radians(t * .twoPi), dec: .zero)
                .sidereallyRotated(by: dc.state.localSiderealOffset)
        }
        
        dc.strokeCurve(horizon, color: artist.horizonFillColor)
        

        for decl in Angle.sunsets {
            let pts = EProjection.sampleCurve(appState: dc.state, mode: .userLocation) { t in
                EPrecession.equatorialVector(ra: .radians(t * .twoPi), dec: decl)
                    .sidereallyRotated(by: dc.state.localSiderealOffset)
            }
            dc.strokeCurve(pts, color: artist.horizonFillColor, width: artist.width)
        }
    }
}

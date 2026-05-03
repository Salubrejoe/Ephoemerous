import SwiftUI
import simd

struct ENSMeridiansLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showNSMeridians else { return }
        for h in stride(from: 0.0, to: 24.0, by: 1.0) {
            let ra = h / 24.0 * Double.twoPi
            let pts = EProjection.sampleCurve(
                appState: dc.state,
                mode: .northSouth
            ) { t in
                EPrecession.equatorialVector(
                    ra:  .radians(ra),
                    dec: .radians((t - 0.5) * Double.pi)
                )
                .sidereallyRotated(by: dc.state.localSiderealOffset)
            }
            dc.strokeCurve(
                pts,
                color: .white.opacity(0.1),
                width: 2
//                width: h == 0.0 ? artist.thickWidth : artist.width
            )
        }
    }
}

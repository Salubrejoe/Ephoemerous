import SwiftUI
import simd

struct EULEquatorTropicsLayer: EGridLayer {
    let artist = EArtist.shared
    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showEquatorTropics else { return }
        for parallel in EKnownParallels.allCases {
            let pts = EProjection.sampleCurve(appState: dc.state, mode: .userLocation) { t in
                EPrecession.equatorialVector(ra: .radians(.twoPi * t), dec: parallel.declination)
                    .sidereallyRotated(by: dc.state.localSiderealOffset)
            }
            dc.strokeCurve(pts, color: artist.color,
                           width: parallel == .equator ? artist.thickWidth : artist.width)
        }
    }
}
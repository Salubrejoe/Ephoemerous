import SwiftUI

struct EEquatorTropicsLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showEquatorTropics else { return }
        for parallel in [EKnownParallels.equator] {
            let pts = EProjection.sampleCurve(appState: dc.state, mode: mode) { t in
                EPrecession.equatorialVector(ra: .radians(.twoPi * t), dec: parallel.declination)
                    .sidereallyRotated(by: dc.state.localSiderealOffset)
            }
            dc.strokeCurve(pts, color: artist.color,
                           width: artist.width)
        }
    }
}

import SwiftUI

struct EEquatorTropicsLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame
    
    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showEquatorTropics else { return }
//        for parallel in Angle.parallels {
        for parallel in [
            Angle.degrees(-89.99),
            Angle.degrees(-80),
            Angle.degrees(-70),
            Angle.degrees(-60),
            Angle.degrees(-50),
            Angle.degrees(-50),
            Angle.degrees(-40),
            Angle.degrees(-30),
            Angle.degrees(-20),
            Angle.degrees(-10),
            Angle.degrees(0),
            Angle.degrees(89.99),
            Angle.degrees(80),
            Angle.degrees(70),
            Angle.degrees(10),
            Angle.degrees(60),
            Angle.degrees(50),
            Angle.degrees(40),
            Angle.degrees(30),
            Angle.degrees(20),
        ] {
            let pts = EProjection.sampleCurve(appState: dc.state, mode: mode) { t in
                EPrecession.equatorialVector(ra: .radians(.twoPi * t), dec: parallel)
                    .sidereallyRotated(by: dc.state.localSiderealOffset)
            }
//            dc.fillCurve(pts, color: artist.color)
            dc.strokeCurve(pts, color: .secondary.opacity(0.1),
                           width: 8.0)
        }
    }
}

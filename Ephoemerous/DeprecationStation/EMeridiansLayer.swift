//import SwiftUI
//import simd
//
//struct EMeridiansLayer: EGridLayer {
//    let artist = EArtist.shared
//    let mode: EProjection.ProjectionFrame
//
//    func draw(in dc: inout EGraphicContext) {
//        let show = mode == .northSouth ? dc.state.showNSMeridians : dc.state.showULMeridians
//        guard show else { return }
//        for h in stride(from: 0.0, to: 24.0, by: artist.meridianStep(mode: mode)) {
//            let ra  = h / 24.0 * Double.twoPi
//            let pts = EProjection.sampleCurve(appState: dc.state, mode: mode) { t in
//                EPrecession.equatorialVector(ra: .radians(ra),
//                                            dec: .radians((t - 0.5) * Double.pi))
//                    .sidereallyRotated(by: dc.state.localSiderealOffset)
//            }
//            dc.strokeCurve(pts, color: artist.horizonFillColor, width: artist.width)
//        }
//    }
//}

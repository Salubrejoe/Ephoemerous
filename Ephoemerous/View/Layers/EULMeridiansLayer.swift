import SwiftUI
import simd

struct EULMeridiansLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showULMeridians else { return }
        let origin = dc.state.observerZenith
        let plane  = -dc.state.observerZenith

        for h in stride(from: 0.0, to: 24.0, by: 3.0) {
            let ra = h / 24.0 * Double.twoPi
            let pts: [CGPoint?] = (0...360).map { i in
                let t   = Double(i) / 360.0
                let vec = EPrecession.equatorialVector(
                    ra:  .radians(ra),
                    dec: .radians((t - 0.5) * Double.pi)
                ).sidereallyRotated(by: dc.state.localSiderealOffset)
                return EProjection.project(vec, origin: origin, plane: plane)
            }
            dc.strokeCurve(
                pts,
                color: .baseSlate.opacity(0.75),
                width: 2
            )
        }
    }
}

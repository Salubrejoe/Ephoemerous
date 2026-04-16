import SwiftUI
import simd


struct EPHHorizonLayer: EGridLayer {

    func draw(in dc: inout EGraphicContext) {
        let O = dc.state.originVector
        let P = dc.state.planeVector
        let z = dc.state.observerZenith
        let (e1, e2) = EProjection.tangentBasis(z)

        let pts = EProjection.sampleCurve(steps: 360, origin: O, plane: P) { t in
            let θ = t * 2 * Double.pi
            return cos(θ) * e1 + sin(θ) * e2
        }
        dc.strokeCurve(pts, color: .green)
    }
}

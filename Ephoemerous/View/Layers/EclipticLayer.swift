import SwiftUI
import simd

struct EclipticLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showEcliptic else { return }
        
        let pts = EProjection.sampleEcliptic(appState: dc.state, mode: mode)
        dc.strokeCurve(
            pts,
            color: .quaternarySystemFill,
            width: 4.0
        )
    }
}

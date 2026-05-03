import SwiftUI
import simd

struct EULEclipticLayer: EGridLayer {
    let artist = EArtist.shared
    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showEcliptic else { return }
        let pts = EProjection.sampleEcliptic(appState: dc.state, mode: .userLocation)
        dc.strokeCurve(pts, color: artist.eclColor, width: artist.eclWidth)
    }
}
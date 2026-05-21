import SwiftUI

// The watch-face disc fill that sits behind the celestial content in
// clock mode. Visibility and scale are driven by `state.chromeOpacity`
// and `state.chromeRadiusScale`, so the disc fades + scales during the
// mode toggle (expands on Clock→Travel, collapses on Travel→Clock).
struct WatchBackgroundLayer: EGridLayer {

    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        let opacity = dc.state.chromeOpacity
        guard opacity > 0.001 else { return }

        var local = dc.ctx
        local.opacity = opacity
        
        local.addFilter(
            .shadow(
                color: .systemBackground,
                radius: 4,
                x: 0,
                y: 1,
//                blendMode: .destinationOver,
//                options: .shadowAbove
            )
        )
        
//        local.addFilter(.brightness(0.1))
        local.fill(artist.chromePath(in: dc), with: .color(.systemBackground))
    }
}

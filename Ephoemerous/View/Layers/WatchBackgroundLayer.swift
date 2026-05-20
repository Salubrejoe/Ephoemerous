import SwiftUI

// The watch-face disc fill that sits behind the celestial content in
// clock mode. Visibility and scale are driven by `state.chromeOpacity`
// and `state.chromeRadiusScale`, so the disc fades + scales during the
// mode toggle (expands on Clock→Travel, collapses on Travel→Clock).
struct WatchBackgroundLayer: EGridLayer {

    func draw(in dc: inout EGraphicContext) {
        let opacity = dc.state.chromeOpacity
        guard opacity > 0.001 else { return }
        let scale = dc.state.chromeRadiusScale

        let cx = dc.size.width  / 2 + dc.state.renderedOffset.y
        let cy = dc.size.height / 2 + dc.state.renderedOffset.x
        let r  = (dc.state.renderedScale * EArtist.shared.clipRadius
                  + EArtist.shared.clipBleed) * scale

        var local = dc.ctx
        local.opacity = opacity
        local.addFilter(.shadow(color: .tertiary, radius: 2))

        let disc = Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                          width: 2 * r, height: 2 * r))
        local.fill(disc, with: .color(.systemBackground))
    }
}

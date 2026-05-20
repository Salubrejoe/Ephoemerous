import SwiftUI

// The watch-face disc fill that sits behind the celestial content in clock
// mode. Visibility is driven by the chrome canvas's opacity in
// `CelestialCanva` (`renderedClockOpacity`) — no longer self-gates on
// `appMode`, so it can fade in during a Travel→Clock transition.
struct WatchBackgroundLayer: EGridLayer {

    func draw(in dc: inout EGraphicContext) {
        let cx = dc.size.width  / 2 + dc.state.renderedOffset.y
        let cy = dc.size.height / 2 + dc.state.renderedOffset.x
        let r  = dc.state.renderedScale * EArtist.shared.clipRadius
               + EArtist.shared.clipBleed - 10
        let disc = Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                          width: 2 * r, height: 2 * r))
        dc.ctx.addFilter(.shadow(color: .tertiary, radius: 1))
        dc.ctx.fill(disc, with: .color(.systemBackground))

        let ringR = r + 6
        let ring = Path(ellipseIn: CGRect(x: cx - ringR, y: cy - ringR,
                                          width: 2 * ringR, height: 2 * ringR))
        
        dc.ctx.stroke(ring, with: .color(.systemBackground), lineWidth: 4)
    }
}

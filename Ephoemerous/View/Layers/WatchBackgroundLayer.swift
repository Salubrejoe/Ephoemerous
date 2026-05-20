import SwiftUI

// Back-most layer of the clipped inner canvas: the night-sky disc fill.
//
// Drawn through the same EGraphicContext as every other layer, inside the
// inner canvas's crown-disc clip — so it is anchored to the viewport
// exactly like the stars and the crown. No standalone SwiftUI shape
// positioned by renderedOffset to drift out of sync.
//
// Travel mode keeps its plain full-screen fill in MainView (a flat
// rectangle has no scale/offset positioning, so nothing to anchor).
struct WatchBackgroundLayer: EGridLayer {

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.appMode == .clock else { return }

        let cx = dc.size.width  / 2 + dc.state.renderedOffset.y
        let cy = dc.size.height / 2 + dc.state.renderedOffset.x
        let r  = dc.state.renderedScale * EArtist.shared.clipRadius
               + EArtist.shared.clipBleed - 8
        let disc = Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                          width: 2 * r, height: 2 * r))

        dc.ctx.fill(disc, with: .color(.systemBackground))

        let ringR = r + 6
        let ring = Path(ellipseIn: CGRect(x: cx - ringR, y: cy - ringR,
                                          width: 2 * ringR, height: 2 * ringR))
        dc.ctx.stroke(ring, with: .color(.systemBackground), lineWidth: 4)
    }
}

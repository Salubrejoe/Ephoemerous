import SwiftUI

// The thin `.systemBackground`-coloured ring that haloes the watch
// chrome. Drawn as the top-most layer so it sits above everything else
// — its job is to mask stray pixels that bleed past the chrome edge
// (horizon strokes, deformed squircles, sample-step jaggies).
//
// Geometry mirrors `WatchBackgroundLayer`'s disc: both ride
// `chromeOpacity` and `chromeRadiusScale` so the rim fades and resizes
// in lockstep during the Clock↔Travel transition.
struct WatchRimLayer: EGridLayer {

    func draw(in dc: inout EGraphicContext) {
        let opacity = dc.state.chromeOpacity
        guard opacity > 0.001 else { return }
        let scale = dc.state.chromeRadiusScale

        let cx = dc.size.width  / 2 + dc.renderedOffset.y
        let cy = dc.size.height / 2 + dc.renderedOffset.x
        let r  = (dc.renderedScale * EArtist.shared.clipRadius
                  + EArtist.shared.clipBleed - 14) * scale

        var local = dc.ctx
        local.opacity = opacity
//        local.addFilter(
//            .shadow(
////                color: .secondary,
//                color: .tertiary,
//                radius: 2,
//                x: 0,
//                y: 1,
////                blendMode: .destinationOver,
////                options: .shadowAbove
//            )
//        )
////        local.addFilter(.shadow(color: .tertiary, radius: 2))

        
        let ringR = r + 6 * scale
        let ring  = Path(ellipseIn: CGRect(x: cx - ringR, y: cy - ringR,
                                           width: 2 * ringR, height: 2 * ringR))
//        local.stroke(ring, with: .color(.tertiarySystemBackground), lineWidth: 2 * scale)
    }
}

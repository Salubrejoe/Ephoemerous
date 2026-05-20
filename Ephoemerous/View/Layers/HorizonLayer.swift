import SwiftUI
import simd

/*
 let cx   = dc.size.width  / 2 + dc.state.renderedOffset.y
 let cy   = dc.size.height / 2 + dc.state.renderedOffset.x
 let r    = dc.state.renderedScale * EArtist.shared.clipRadius
 + EArtist.shared.clipBleed
 let rect = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
 let path = Squircle(corners: 12, bulge: 3).path(in: rect)
 dc.ctx.stroke(path, with: .color(.tertiaryLabel), lineWidth: artist.eclWidth)
 */

struct HorizonLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showHorizon else { return }

        for decl in Angle.sunsets {
            let pts = EProjection.sampleCurve(appState: dc.state, mode: .userLocation) { t in
                EPrecession.equatorialVector(ra: .radians(t * .twoPi), dec: decl)
                    .sidereallyRotated(by: dc.state.localSiderealOffset)
            }
            dc.fillCurve(
                pts,
                color: .quaternarySystemFill,)
        }
    }
}

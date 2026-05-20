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

        // In clock mode the horizon is contained within the watch chrome.
        // Work on a local copy of the graphics context so the clip dies
        // with this layer and doesn't leak into anything drawn after.
        // The clip radius rides `chromeRadiusScale` so it grows / shrinks
        // alongside the chrome during the Clock↔Travel transition.
        var local = dc
        if dc.state.appMode == .clock {
            let cx = dc.size.width  / 2 + dc.state.renderedOffset.y
            let cy = dc.size.height / 2 + dc.state.renderedOffset.x
            let r  = (dc.state.renderedScale * artist.clipRadius
                      + artist.clipBleed) * dc.state.chromeRadiusScale
            local.ctx.clip(to: Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                                      width: 2 * r, height: 2 * r)))
        }

        for decl in Angle.sunsets {
            let pts = EProjection.sampleCurve(
                appState:           local.state,
                mode:               .userLocation,
                negateUserLocation: false
            ) { t in
                EPrecession
                    .equatorialVector(ra: .radians(t * .twoPi), dec: decl)
                    .sidereallyRotated(by: local.state.localSiderealOffset)
            }
            local.fillCurve(pts, color: .quaternarySystemFill)
        }
    }
}

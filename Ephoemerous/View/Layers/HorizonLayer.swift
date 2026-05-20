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

    private let corners : Int     = 24
    private let bulge   : CGFloat = 2.5
    private let width   : CGFloat = 2

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showHorizon else { return }

        // Two separate local copies of the graphics context: `fillCurve`
        // clips cumulatively, so the band-loop's clips would otherwise
        // eat into the horizon squircle drawn afterwards.
        // The chrome clip is computed once and applied to both copies.
        // Its radius rides `chromeRadiusScale` so it grows / shrinks
        // alongside the chrome during the Clock↔Travel transition.
        var chromeClip: Path? = nil
        if dc.state.appMode == .clock {
            let cx = dc.size.width  / 2 + dc.state.renderedOffset.y
            let cy = dc.size.height / 2 + dc.state.renderedOffset.x
            let r  = (dc.state.renderedScale * artist.clipRadius
                      + artist.clipBleed) * dc.state.chromeRadiusScale
            chromeClip = Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                                width: 2 * r, height: 2 * r))
        }

        // Twilight bands (currently .clear — colour will return later).
        var bands = dc
        if let clip = chromeClip { bands.ctx.clip(to: clip) }
        for decl in Angle.sunsets where decl != .zero {
            let pts = EProjection.sampleCurve(
                appState:           bands.state,
                mode:               .userLocation,
                negateUserLocation: false
            ) { t in
                EPrecession
                    .equatorialVector(ra: .radians(t * .twoPi), dec: decl)
                    .sidereallyRotated(by: bands.state.localSiderealOffset)
            }
            bands.fillCurve(pts, color: .tertiarySystemFill)
        }

        // Horizon great circle as a deformable squircle: each projection
        // sample is pushed radially outward from the curve's centroid by
        // `Squircle.lameRadius(θ)`. This rides whatever shape the
        // projection produces — true circle in pure stereographic, or a
        // deformed conic when the origin and plane fall out of sync —
        // and lays 24 evenly-spaced bumps over it. Routed through
        // `strokeCurve` so the projection→screen mapping is handled.
        var rim = dc
        if let clip = chromeClip { rim.ctx.clip(to: clip) }
        let pts = EProjection.sampleCurve(
            appState:           rim.state,
            mode:               .userLocation,
            negateUserLocation: false
        ) { t in
            EPrecession
                .equatorialVector(ra: .radians(t * .twoPi), dec: .horizon)
                .sidereallyRotated(by: rim.state.localSiderealOffset)
        }.compactMap { $0 }
        guard pts.count >= 8 else { return }

        let n      = CGFloat(pts.count)
        let cx     = pts.map(\.x).reduce(0, +) / n
        let cy     = pts.map(\.y).reduce(0, +) / n
        let corn   = CGFloat(corners)
        let bumped : [CGPoint?] = pts.map { p in
            let dx = p.x - cx
            let dy = p.y - cy
            let θ  = atan2(dy, dx)
            let k  = Squircle.lameRadius(angle: θ, corners: corn, bulge: bulge)
            return CGPoint(x: cx + dx * k, y: cy + dy * k)
        }
//        rim.ctx.addFilter(.shadow(color: .baseOrange, radius: 2))
        rim.strokeCurve(bumped, color: .tertiarySystemFill, width: width)
    }
}

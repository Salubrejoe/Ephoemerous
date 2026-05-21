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

    private let corners : Int     = 90
    private let bulge   : CGFloat = 2.1
    private let width   : CGFloat = 2

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showHorizon else { return }

        // Two separate local copies of the graphics context: `fillCurve`
        // clips cumulatively, so the band-loop's clips would otherwise
        // eat into the horizon squircle drawn afterwards.
        // The chrome shape is shared with `WatchBackgroundLayer` via
        // `EArtist.chromePath` — clip + disc fill always agree.
        let chromeShape: Path? = dc.state.appMode == .clock
            ? artist.chromePath(in: dc)
            : nil

        // Twilight bands. The chrome interior is pre-filled with the
        // band colour so the band ring reaches the disc edge — the
        // outermost projected band stops well short of the chrome,
        // leaving an unpainted gap otherwise.
        var bands = dc
        if let shape = chromeShape {
            bands.ctx.clip(to: shape)
            bands.ctx.fill(shape, with: .color(.tertiarySystemFill))
        }
        for decl in Angle.sunsets where decl != .zero {
            let pts = EProjection.sampleCurve(
                appState:           bands.state,
                mode:               .userLocation,
                negateUserLocation: false
            ) { t in
                EPrecession
                    .equatorialVector(ra: .radians(t * .twoPi), dec: decl)
                    .sidereallyRotated(by: bands.state.localSiderealOffset)
            }.compactMap { $0 }
            guard pts.count >= 8 else { continue }
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
        if let shape = chromeShape { rim.ctx.clip(to: shape) }
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
        rim.strokeCurve(bumped(pts), color: .tertiarySystemFill, width: width)
    }

    /// Push each sample radially outward from the curve's centroid by
    /// `Squircle.lameRadius(θ)`. Lays the squircle's bulge pattern over
    /// whatever shape the projection produces — circle in pure
    /// stereographic, deformed conic otherwise.
    private func bumped(_ pts: [CGPoint]) -> [CGPoint?] {
        let n    = CGFloat(pts.count)
        let cx   = pts.map(\.x).reduce(0, +) / n
        let cy   = pts.map(\.y).reduce(0, +) / n
        let corn = CGFloat(corners)
        return pts.map { p in
            let dx = p.x - cx
            let dy = p.y - cy
            let θ  = atan2(dy, dx)
            let k  = Squircle.lameRadius(angle: θ, corners: corn, bulge: bulge)
            return CGPoint(x: cx + dx * k, y: cy + dy * k)
        }
    }
}

import SwiftUI
import simd
import LoreKit

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
    private let width   : CGFloat = 1

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
//            bands.ctx.fill(shape, with: .color(.tertiarySystemFill))
        }
        // Twilight bands: small circles at constant altitude just
        // above / below the horizon (the values in `Angle.sunsets`
        // are altitudes, not declinations — e.g. `.civil` = -6° below
        // the horizon, `.astronomical` = -18°). Filled with reduced
        // opacity so they stack into a smooth twilight gradient.
        for alt in Angle.sunsets where alt != .horizon {
            let pts = EProjection.sampleCurve(viewpoint: bands.viewpoint) { t in
                bands.viewpoint.skyPoint(altitude: alt, at: t)
            }.compactMap { $0 }
            guard pts.count >= 8 else { continue }
//            bands.fillCurve(pts, color: artist.sunsetStrokeColor.opacity(0.4))
//            bands.strokeCurve(pts, color: artist.sunsetStrokeColor)
        }

        // Horizon great circle as a deformable squircle: each projection
        // sample is pushed radially outward from the curve's centroid by
        // `Squircle.lameRadius(θ)`. This rides whatever shape the
        // projection produces — true circle in pure stereographic, or a
        // deformed conic when the origin and plane fall out of sync —
        // and lays 24 evenly-spaced bumps over it. Routed through
        // `strokeCurve` so the projection→screen mapping is handled.
        // Horizon great circle: alt = 0, i.e. the locus perpendicular
        // to the observer's zenith. Projects to a true circle of
        // radius 2 (projection units) centred on screen — the
        // visible-sky boundary in the astrolabe sense. Stars / sun /
        // moon inside this rim are above the horizon right now;
        // outside are below.
        var rim = dc
//        if let shape = chromeShape { rim.ctx.clip(to: shape) }
        let pts = EProjection.sampleCurve(viewpoint: rim.viewpoint) { t in
            rim.viewpoint.skyPoint(altitude: .horizon, at: t)
        }.compactMap { $0 }
        guard pts.count >= 8 else { return }
        rim.fillCurve(bumped(pts), color: artist.horizonFillColor)
//        rim.strokeCurve(bumped(pts), color: artist.horizonFillColor, width: width)
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

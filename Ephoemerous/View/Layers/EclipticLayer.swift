import SwiftUI
import simd

// Renders the ecliptic as a 6-corner squircle rim instead of its true
// projected curve.
//
// Why this works cleanly: `EProjection.project` is stereographic, and
// stereographic projection preserves circles — so the ecliptic (a great
// circle on the celestial sphere) lands as a perfect 2D circle in
// projection space. Centroid + mean radius therefore give us the
// squircle's centre and size exactly.
//
// The rim is anchored to the Sun: the squircle's `t = 0` rim point (a
// side-midpoint for an even corner count) follows the Sun's projected
// direction from the ecliptic centre, so the shape rotates through the
// year as the Sun travels round the ecliptic.
struct EclipticLayer: EGridLayer {

    let artist = EArtist.shared
    let mode  : EProjection.ProjectionFrame

    private let corners : Int     = 12
    private let bulge   : CGFloat = 3
    private let width   : CGFloat = 4

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showEcliptic else { return }

        let samples = EProjection.sampleEcliptic(appState: dc.state, mode: mode)
            .compactMap { $0 }
        guard samples.count >= 8 else { return }

        let (centre, radius) = fitCircle(samples)
        guard radius > 0.0001 else { return }

        let rotation = sunAnchor(centre: centre, in: dc)
        let rect     = CGRect(x:      centre.x - radius,
                              y:      centre.y - radius,
                              width:  2 * radius,
                              height: 2 * radius)
        let pts      = Squircle(corners: corners, bulge: bulge, rotation: rotation)
                          .vertices(in: rect)
                          .map { Optional.some($0) }

        dc.strokeCurve(pts, color: .quaternarySystemFill, width: width)
    }

    // Stereographic guarantees the samples are concyclic, so centroid +
    // mean radius are exact for a fully-visible ecliptic. Falls back
    // gracefully if a few samples were nil (partial visibility).
    private func fitCircle(_ pts: [CGPoint]) -> (centre: CGPoint, radius: CGFloat) {
        let n  = CGFloat(pts.count)
        let cx = pts.map(\.x).reduce(0, +) / n
        let cy = pts.map(\.y).reduce(0, +) / n
        let r  = pts.map { hypot($0.x - cx, $0.y - cy) }.reduce(0, +) / n
        return (CGPoint(x: cx, y: cy), r)
    }

    private func sunAnchor(centre: CGPoint, in dc: EGraphicContext) -> Angle {
        let lambda = ESunPosition.eclipticLongitude(for: dc.state.renderedObservationDate)
        let th     = dc.state.localSiderealOffset.radians
        let (c, s) = (cos(th), sin(th))
        let eq     = SIMD3<Double>.eclipticPoint(lambda: lambda)
        let Q      = SIMD3(eq.x * c - eq.y * s,
                           eq.x * s + eq.y * c,
                           eq.z)
        guard let sun = EProjection.project(Q, appState: dc.state, mode: mode) else {
            return .zero
        }
        return .radians(atan2(sun.y - centre.y, sun.x - centre.x))
    }
}

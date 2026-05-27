import SwiftUI
import LoreKit

// MARK: - Horizon
// Visible-sky fill + bumped-rim helper for `HorizonLayer` — a soft
// wash inside the alt = 0 great circle marking the patch of sky
// currently above the observer's horizon, with a many-corner
// squircle "bump" laid over each projection sample so the rim
// reads as a soft scallop rather than a clean circle.
extension EArtist {

    var horizonFillColor   : Color  { .tertiary }
    var horizonBumpCorners : Int    { 12 }
    var horizonBumpBulge   : CGFloat { 2.2 }

    /// Push each sample radially outward from the curve's centroid
    /// by `Squircle.lameRadius(θ, corners: horizonBumpCorners,
    /// bulge: horizonBumpBulge)`. Lays the squircle's bulge pattern
    /// over whatever shape the projection produces — true circle
    /// in pure stereographic, deformed conic otherwise.
    func bumpedHorizonRim(_ pts: [CGPoint]) -> [CGPoint?] {
        guard !pts.isEmpty else { return [] }
        let n    = CGFloat(pts.count)
        let cx   = pts.map(\.x).reduce(0, +) / n
        let cy   = pts.map(\.y).reduce(0, +) / n
        let corn = CGFloat(horizonBumpCorners)
        return pts.map { p in
            let dx = p.x - cx
            let dy = p.y - cy
            let θ  = atan2(dy, dx)
            let k  = Squircle.lameRadius(angle: θ,
                                         corners: corn,
                                         bulge:   horizonBumpBulge)
            return CGPoint(x: cx + dx * k, y: cy + dy * k)
        }
    }
}

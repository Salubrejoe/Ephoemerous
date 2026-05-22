import SwiftUI

// MARK: - Watch chrome
// Geometry + colour for the watch-face disc and the hour ring around
// it. The disc itself is a squircle (`chromePath`) shared by every
// layer that should be clipped to the chrome — single source of truth
// so tweaking the disc shape can never leave the clip out of sync
// with the fill.
extension EArtist {

    // MARK: Crown stroke
    var crownBorderColor : Color  { .primary }
    var crownBorderWidth : Double { 2.0 }

    // MARK: Disc / clip geometry
    // Shared by the sky clip, sky background, crown and pan bounds.
    //   • clipRadius  — disc radius in NS projection units (dec −30°)
    //   • clipBleed   — px clipped past the disc so the rim is real
    //                   content, not a jagged clip seam
    //   • bezelWidth  — background-tinted ring laid over the old edge;
    //                   (clipBleed − bezelWidth) px peeks past it
    //   • hourRingGap — gap from the disc to the hour-number midline
    var clipRadius  : Double { 2 * sqrt(3) }
    var clipBleed   : Double { 8 }
    var bezelWidth  : Double { 4 }
    var hourRingGap : Double { 20 }

    // MARK: Disc shape
    // Tweak corners / bulge to retune the disc; HorizonLayer's clip
    // and WatchBackgroundLayer's fill both follow.
    var chromeCorners : Int     { 4 }
    var chromeBulge   : CGFloat { 4 }

    /// Screen-space centre + radius of the watch chrome disc. Cheap
    /// `(dx² + dy²) < r²` rejection tests use this — `StarsLayer` and
    /// `SelectedStarsLayer` pre-compute it once per frame to skip stars
    /// projected outside the visible disc in clock mode. The squircle
    /// rim's bumps push past `radius` by ~2 % at corners, so the cull
    /// is marginally tight — irrelevant visually, generous enough not
    /// to clip stars sitting on the disc edge.
    func chromeBounds(in dc: EGraphicContext) -> (centre: CGPoint, radius: CGFloat) {
        let cx = dc.size.width  / 2 + dc.renderedOffset.y
        let cy = dc.size.height / 2 + dc.renderedOffset.x
        let r  = (dc.renderedScale * clipRadius
                  + clipBleed) * dc.state.chromeRadiusScale
        return (CGPoint(x: cx, y: cy), r)
    }

    func chromePath(in dc: EGraphicContext) -> Path {
        let (centre, r) = chromeBounds(in: dc)
        return Squircle(corners: chromeCorners, bulge: chromeBulge)
            .path(in: CGRect(x: centre.x - r, y: centre.y - r,
                             width: 2 * r, height: 2 * r))
    }
}

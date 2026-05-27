import SwiftUI
import LoreKit

// MARK: - Watch chrome
// Geometry + colour for the watch-face disc and the hour ring around
// it. The disc itself is a squircle (`chromePath`) shared by every
// layer that should be clipped to the chrome — single source of truth
// so tweaking the disc shape can never leave the clip out of sync
// with the fill.
extension EArtist {

    // MARK: Disc / clip geometry
    // Shared by the sky clip, sky background, and pan bounds.
    //   • clipRadius — disc radius in projection units; the
    //                  Stars / SelectedStars layers use it to cull
    //                  off-disc stars in clock mode, and Horizon
    //                  uses `chromePath` to clip its fill to the
    //                  watch face.
    //   • clipBleed  — px clipped past the disc so the rim is real
    //                  content, not a jagged clip seam.
    var clipRadius : Double { 2 * sqrt(3) }
    var clipBleed  : Double { 8 }

    // MARK: Disc shape
    // Tweak corners / bulge to retune the disc; HorizonLayer's clip
    // and WatchBackgroundLayer's fill both follow.
    var chromeCorners : Int     { 24 }
    var chromeBulge   : CGFloat { 2.1 }

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

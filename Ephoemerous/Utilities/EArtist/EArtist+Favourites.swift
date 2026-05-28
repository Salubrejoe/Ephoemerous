import SwiftUI

// MARK: - Favourites
// Static "this is a favourite" marker drawn by `FavouritesLayer`.
// Replaces the animated breathing halo (now in DeprecationStation).
// Two roles for the same heart asset:
//
//   • Tier 0 — when the POI badge isn't visible yet, the heart IS
//     the marker. Drawn at the star's projected position.
//   • Tier 1+ — when the badge is visible, the heart is overlaid on
//     the badge's top-leading corner as a small decoration.
//
// One implementation, two call sites — keeps the visual vocabulary
// consistent across zoom levels without any per-frame animation cost.
extension EArtist {

    /// Universal favourite heart. `point` is the centre of the heart
    /// (caller positions accordingly); `size` is the SF Symbol point
    /// size; `color` matches the object's label colour (e.g. star's
    /// spectral class) so the heart reads as part of the same visual
    /// species, not a foreign red sticker. A 1-point shadow (same
    /// `poiShadow` filter used by the rest of the POI system) lifts
    /// the heart off the canvas and gives it the same soft halo as
    /// the badge it decorates.
    func drawFavouriteHeart(at point: CGPoint,
                            size: CGFloat,
                            color: Color,
                            in dc: inout EGraphicContext) {
        var shadowed = dc.ctx
        shadowed.addFilter(poiShadow)
        shadowed.draw(
            Text(Image(systemName: "heart.fill"))
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color),
            at:     point,
            anchor: .center
        )
    }
}

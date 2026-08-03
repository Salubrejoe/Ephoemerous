import SwiftUI
import simd
import LoreKit

// MARK: - FavouritesLayer
// Renders the user's favourites on the canvas — the universal halo +
// always-visible badge treatment that used to live in
// `SelectedStarsLayer` (star-only). Currently only the `.star` cases
// have a visual; other ESkyObject favourites are stored but invisible
// here until their UX lands. Position publishing covers every type so
// taps + focus can resolve any favourite by id.
struct FavouritesLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        // Collect all favourite screen positions into a local
        // snapshot, then publish once at the end with an equality
        // guard. Previously each draw call did one
        // `DispatchQueue.main.async` per favourite (N async hops per
        // frame at 120 Hz). Now: one hop total, and it no-ops when
        // nothing moved. Also fixes a latent stale-key issue —
        // unfavouriting a star used to leave its last position in
        // `favouritePositions` forever.
        var positions: [String: CGPoint] = [:]
        positions.reserveCapacity(dc.state.favourites.count)

        for fav in dc.state.favourites {
            switch fav {
            case .star(let star):
                if let sc = drawStarFavourite(star, in: &dc) {
                    positions[fav.id] = sc
                }
            case .constellation, .sun, .moon, .planet:
                // Constellation favourites are now signalled by
                // `ConstellationNamesLayer` (inline ♥ in the plain-
                // text label) and `ConstellationLinesLayer` (solid
                // coloured stroke). Sun / moon / planet favourite
                // visuals ship when their detail UI gets a favourite
                // button — stored in `favourites` but render
                // silently here for now.
                continue
            }
        }

        let snapshot = positions
        let stateRef = dc.state
        DispatchQueue.main.async {
            if stateRef.favouritePositions != snapshot {
                stateRef.favouritePositions = snapshot
            }
        }
    }

    /// Full favourite treatment for a star — pentagon POI badge with
    /// the heart marker overlaid. Returns the projected screen
    /// position for the caller to collect into the per-frame
    /// snapshot, or `nil` when the star's vector failed to project
    /// (off-globe / behind viewer).
    @discardableResult
    private func drawStarFavourite(_ star: EStar,
                                   in dc: inout EGraphicContext) -> CGPoint? {
        let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                              to: dc.renderedObservationDate)
        let th = dc.localSiderealOffset.radians
        let (c, s) = (cos(th), sin(th))
        let v = EPrecession.equatorialVector(ra: pRA, dec: pDec)
        let Q = SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)

        guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { return nil }
        let sc = dc.toScreen(proj)

        // Favourite signal — a static heart.
        //
        //   Tier 0 (scale < badgeIn): the heart IS the marker.
        //                             Drawn at the projected position,
        //                             replacing the squircle dot.
        //   Tier 1+ (scale ≥ badgeIn): regular POI badge with the
        //                              heart overlaid on the
        //                              top-leading corner.
        let style      = artist.poiStyle(for: .followedStar(star))
        let heartColor = star.spectralClass.color
        let promo      = dc.poiPromotion(forObjectID: ESkyObject.star(star).id)

        // Below the badge tier the heart IS the marker — UNLESS this
        // favourite is the selected one. We pan to a selection without
        // zooming, so a favourite tapped/searched at low zoom must still
        // promote; fall through to the full badge in that case (drawPOILabel
        // forces the reveal from `promo`).
        if dc.renderedScale < style.badgeIn && promo <= 0 {
            drawFavouriteHeart(at: sc, size: 8, color: heartColor, in: &dc)
            return sc
        }

        artist.drawPOILabel(
            at:        sc,
            glyph:     .symbol(.starFill),
            text:      star.displayName,
            category:  .followedStar(star),
            drawDot:   false,    // heart handles the low-zoom case
            promotion: promo,
            in:        &dc
        )
        let heartCorner = CGPoint(x: sc.x - style.badgeSize / 2,
                                  y: sc.y - style.badgeSize / 2)
        drawFavouriteHeart(at: heartCorner, size: 7, color: heartColor, in: &dc)
        return sc
    }

    /// Static "this is a favourite" heart. Moved here from
    /// `EArtist+Favourites` so the drawing logic lives with the layer that
    /// owns it — keeping `EArtist` free of `EGraphicContext` / the
    /// production canvas. Two roles: the tier-0 marker (heart IS the dot)
    /// and a top-leading corner decoration on the badge at higher zoom.
    private func drawFavouriteHeart(at point: CGPoint,
                                    size: CGFloat,
                                    color: Color,
                                    in dc: inout EGraphicContext) {
        var shadowed = dc.ctx
        shadowed.addFilter(artist.poiShadow)
        shadowed.draw(
            Text(Image(symbol: .heartFill))
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color),
            at:     point,
            anchor: .center
        )
    }
}

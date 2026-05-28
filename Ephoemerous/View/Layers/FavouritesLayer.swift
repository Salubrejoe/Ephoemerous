import SwiftUI
import simd

// MARK: - FavouritesLayer
// Renders the user's favourites on the canvas — the universal halo +
// always-visible badge treatment that used to live in
// `SelectedStarsLayer` (star-only). Currently only the `.star` cases
// have a visual; other ESkyObject favourites are stored but invisible
// here until their UX lands. Position publishing covers every type so
// taps + focus can resolve any favourite by id.
struct FavouritesLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        // Clock-mode disc cull, computed once. Favourites projected
        // outside the chrome still get their screen position recorded
        // (other UI reads `favouritePositions`) but skip the breathing
        // halo + badge draw — both would render off-disc.
        let inClock  = dc.state.appMode == .clock
        let chrome   = artist.chromeBounds(in: dc)
        let chromeR2 = chrome.radius * chrome.radius

        for fav in dc.state.favourites {
            switch fav {
            case .star(let star):
                drawStarFavourite(star, id: fav.id, in: &dc,
                                  inClock: inClock,
                                  chromeCentre: chrome.centre,
                                  chromeR2:     chromeR2)
            case .sun, .moon, .planet, .constellation:
                // Visual treatment for these categories ships when
                // their detail UI gets a favourite button — they're
                // stored in `favourites` but render silently for now.
                continue
            }
        }
    }

    /// Full favourite treatment for a star — breathing halo behind a
    /// pentagon POI badge (early thresholds so the badge is visible at
    /// default zoom). Identical to the legacy `SelectedStarsLayer`
    /// behaviour, just routed through the new `favouritePositions`
    /// channel and the unified favourites list.
    private func drawStarFavourite(_ star: EStar,
                                   id: String,
                                   in dc: inout EGraphicContext,
                                   inClock: Bool,
                                   chromeCentre: CGPoint,
                                   chromeR2: CGFloat) {
        let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                              to: dc.renderedObservationDate)
        let th = dc.localSiderealOffset.radians
        let (c, s) = (cos(th), sin(th))
        let v = EPrecession.equatorialVector(ra: pRA, dec: pDec)
        let Q = SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)

        guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { return }
        let sc       = dc.toScreen(proj)
        let stateRef = dc.state
        DispatchQueue.main.async { stateRef.favouritePositions[id] = sc }

        if inClock {
            let dx = sc.x - chromeCentre.x
            let dy = sc.y - chromeCentre.y
            guard dx * dx + dy * dy < chromeR2 else { return }
        }

        // Favourite signal — a static heart. No more breathing halo,
        // no per-frame animation cost.
        //
        //   Tier 0 (scale < badgeIn): the heart IS the marker.
        //                             Drawn at the projected position,
        //                             replacing the squircle dot.
        //   Tier 1+ (scale ≥ badgeIn): regular POI badge with the
        //                              heart overlaid on the
        //                              top-leading corner.
        let style      = artist.poiStyle(for: .followedStar(star))
        let heartColor = star.spectralClass.color
        if dc.renderedScale < style.badgeIn {
            artist.drawFavouriteHeart(at: sc, size: 8, color: heartColor, in: &dc)
            return
        }

        artist.drawPOILabel(
            at:       sc,
            glyph:    .sfSymbol("star"),
            text:     star.displayName,
            category: .followedStar(star),
            drawDot:  false,    // heart handles the low-zoom case
            in:       &dc
        )
        let heartCorner = CGPoint(x: sc.x - style.badgeSize / 2,
                                  y: sc.y - style.badgeSize / 2)
        artist.drawFavouriteHeart(at: heartCorner, size: 7, color: heartColor, in: &dc)
    }
}

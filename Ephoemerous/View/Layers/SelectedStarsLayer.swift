import SwiftUI
import simd

struct SelectedStarsLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        // Opening a constellation no longer paints its figure-stars as
        // selected — constellations are now their own tap-target class
        // (ConstellationNamesLayer + ObjectsTrackingOverlay), so this
        // layer is purely about user-selected stars.
        let currentStars = dc.state.selectedStars

        // Clock-mode disc cull, computed once. Selected stars projected
        // outside the chrome still get their screen position recorded
        // (other UI reads `selectedStarPositions`) but skip the
        // breathing halo + label draw — both would render off-disc.
        let inClock  = dc.state.appMode == .clock
        let chrome   = artist.chromeBounds(in: dc)
        let chromeR2 = chrome.radius * chrome.radius

        for star in currentStars {
            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let th = dc.localSiderealOffset.radians
            let (c, s) = (cos(th), sin(th))
            let v = EPrecession.equatorialVector(ra: pRA, dec: pDec)
            let Q = SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)

            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)

            let name = star.name; let pos = sc; let state = dc.state
            DispatchQueue.main.async { state.selectedStarPositions[name] = pos }

            if inClock {
                let dx = sc.x - chrome.centre.x
                let dy = sc.y - chrome.centre.y
                guard dx * dx + dy * dy < chromeR2 else { continue }
            }

            // Breathing halo behind the badge — kept as the "this
            // star is followed" signal at all zoom levels.
            let starR = CGFloat(artist.starRadius(star, in: dc, twinkling: false)) * 0.5
                      * CGFloat(pow(dc.renderedScale, artist.starZoomExp))
            artist.drawBreathingHalo(at:         sc,
                                     starRadius: starR,
                                     color:      star.spectralClass.color,
                                     time:       dc.animationTime,
                                     in:         &dc)

            // Apple-Maps-style badge replaces the star dot at this
            // screen position. The halo above reads as "behind" it.
            // `drawDot: true` shows a small tinted dot below the
            // badge-in threshold so a followed star is still visible
            // when the user zooms out.
            artist.drawPOILabel(
                at:       sc,
                glyph:    .sfSymbol("star"),
                text:     star.displayName,
                category: .followedStar(star),
                drawDot:  true,
                in:       &dc
            )
        }
    }
}

import SwiftUI
import simd

struct SelectedStarsLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showSelectedStars else { return }
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
                                                  to: dc.state.renderedObservationDate)
            let th = dc.state.localSiderealOffset.radians
            let (c, s) = (cos(th), sin(th))
            let v = EPrecession.equatorialVector(ra: pRA, dec: pDec)
            let Q = SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)

            guard let proj = EProjection.project(
                Q,
                appState: dc.state,
                mode: mode
            ) else { continue }
            let sc = dc.toScreen(proj)

            let name = star.name; let pos = sc; let state = dc.state
            DispatchQueue.main.async { state.selectedStarPositions[name] = pos }

            if inClock {
                let dx = sc.x - chrome.centre.x
                let dy = sc.y - chrome.centre.y
                guard dx * dx + dy * dy < chromeR2 else { continue }
            }

            let isSelected  = dc.state.selectedStars.contains(where: { $0.name == star.name })
            let isDisplayed = dc.state.currentlyDisplayedStar == star
            artist.drawSelectedStar(star, at: sc,
                                    isSelected: isSelected,
                                    isCurrentlyDisplayed: isDisplayed,
                                    showLabel: dc.state.scale >= dc.state.canvasSize.height / 6,
                                    in: &dc)
        }
    }
}

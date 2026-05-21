import SwiftUI
import simd

struct SelectedStarsLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showSelectedStars else { return }
        let currentStars = dc.state.selectedStars + (dc.state.currentlyDisplayedConstellation?.stars ?? [])
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

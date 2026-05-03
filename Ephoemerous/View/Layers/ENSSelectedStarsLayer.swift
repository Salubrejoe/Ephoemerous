
import SwiftUI
import simd


struct ENSSelectedStarsLayer: EGridLayer {
    
    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showSelectedStars else { return }
        
        let currentStars = dc.state.selectedStars + (dc.state.currentlyDisplayedConstellation?.stars ?? [])
        
        for star in currentStars {
            let (pRA, pDec) = EPrecession.precess(
                ra: star.rightAscension,
                dec: star.declination,
                to: dc.state.renderedObservationDate
            )
            let θ = dc.state.localSiderealOffset.radians
            let (c, s) = (cos(θ), sin(θ))
            let v = EPrecession.equatorialVector(ra: pRA, dec: pDec)
            let Q = SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
            
            guard let proj = EProjection.project(
                Q,
                appState: dc.state,
                mode: .northSouth
            ) else { return }
            let sc = dc.toScreen(proj)
            let name = star.name; let pos = sc; let state = dc.state; DispatchQueue.main.async { state.selectedStarPositions[name] = pos }
            
            // Ring -- half size for constellation-only stars
            let isSelected = dc.state.selectedStars.contains(where: { $0.name == star.name })
            let r: CGFloat = isSelected ? 9 : 4.5
            let ring = Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r, width: r * 2, height: r * 2))
            dc.ctx.stroke(ring, with: .color(star.spectralClass.color), lineWidth: isSelected ? 1.5 : 0.75)
            
            // Label
            
            let isCurrentlySeclected = dc.state.currentlyDisplayedStar == star
            let correctFont = isCurrentlySeclected ? Font.body.weight(.heavy) : Font.footnote.weight(.light)
            if dc.state.scale >= 90 {
                dc.ctx.draw(
                    Text(star.displayName)
                        .font(correctFont)
                        .foregroundStyle(star.spectralClass.color.opacity(0.9)),
                    at: CGPoint(x: sc.x + 12, y: sc.y - 4),
                    anchor: .leading
                )
            }
        }
    }
}


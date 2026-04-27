
import SwiftUI
import simd


struct ENSSelectedStarsLayer: EGridLayer {
    
    func draw(in dc: inout EGraphicContext) {
        
        for star in dc.state.selectedStars {
            let (pRA, pDec) = EPrecession.precess(
                ra: star.rightAscension,
                dec: star.declination,
                to: dc.state.observationDate
            )
            let θ = dc.state.precessedSiderealOffset.radians
            let (c, s) = (cos(θ), sin(θ))
            let v = EPrecession.equatorialVector(ra: pRA, dec: pDec)
            let Q = SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
            
            guard let proj = EProjection.project(
                Q,
                appState: dc.state,
                mode: .northSouth
            ) else { return }
            let sc = dc.toScreen(proj)
            
            // Ring
            let ring = Path(ellipseIn: CGRect(x: sc.x - 9, y: sc.y - 9, width: 18, height: 18))
            dc.ctx.stroke(ring, with: .color(star.spectralClass.color), lineWidth: 1.5)
            
            // Label
            dc.gridLabel(at: CGPoint(x: sc.x + 12, y: sc.y - 4), text: star.displayName)
        }
    }
}


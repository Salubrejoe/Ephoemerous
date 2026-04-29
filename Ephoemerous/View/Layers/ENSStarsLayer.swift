
import SwiftUI



struct ENSStarsLayer: EGridLayer {
    let artist = EArtist.shared
    
    func draw(in dc: inout EGraphicContext) {
        
        for star in dc.state.stars {
            
            let (pRA, pDec) = EPrecession.precess(
                ra: star.rightAscension,
                dec: star.declination,
                to: dc.state.renderedObservationDate
            )
            
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.state.precessedSiderealOffset)
            
            if let projPoint = EProjection.project(
                Q,
                appState: dc.state,
                mode: .northSouth
            ) {
                
                let screenPoint = dc.toScreen(projPoint)
                
                guard artist.starPointFallsWithinMarigin(screenPoint, in: dc) else { continue }
                
                let r = artist.starRadius(star, in: dc)
                // Soft glow behind the star
                var glow = dc.ctx
                glow.addFilter(.blur(radius: r * AstroConstants.starGlowBlurRatio))
//                glow.addFilter(.shadow(color: .secondary, radius: 4, options: .shadowOnly))
                glow.fill(
                    Path(ellipseIn: CGRect(x: screenPoint.x - r, y: screenPoint.y - r, width: r * 2, height: r * 2)),
                    with: .color(star.spectralClass.color.opacity(0.45))
                )

                dc.fillDot(
                    at: screenPoint,
                    radius: r,
                    color: star.spectralClass.color
                )
            }
        }
    }
}





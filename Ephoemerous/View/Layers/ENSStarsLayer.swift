
import SwiftUI



struct ENSStarsLayer: EGridLayer {
    let artist = EArtist.shared
    
    func draw(in dc: inout EGraphicContext) {
        
        for star in dc.state.stars {
            
            let (pRA, pDec) = EPrecession.precess(
                ra: star.rightAscension,
                dec: star.declination,
                to: dc.state.observationDate
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
                dc.fillDot(
                    at: screenPoint,
                    radius: r,
                    color: star.spectralClass.color
                )
            }
        }
    }
}





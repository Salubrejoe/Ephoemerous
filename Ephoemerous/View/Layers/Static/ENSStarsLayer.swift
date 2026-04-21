
import SwiftUI



struct ENSStarsLayer: EGridLayer {
    let artist = EArtist.shared
    let stars: [EStar] = StarDatabase.shared.workableStars .filter {
        ($0.magnitude < 4.5)
        && ($0.constellation.isCool)
//        && ($0.constellation.isZodiacSign)
    }
    
    
    func draw(in dc: inout EGraphicContext) {
        let proj = ENSProjection(siderealOffset: dc.state.precessedSiderealOffset)
        
        for star in stars {
           
            let (pRA, pDec) = EPrecession.precess(
                ra: star.rightAscension,
                dec: star.declination,
                to: dc.state.observationDate
            )
            
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: proj.siderealOffset)
            
            if let projPoint = EProjection.project(Q, origin: proj.origin, plane: proj.plane) {
                
                let screenPoint = dc.toScreen(projPoint)
                
                guard artist.starPointFallsWithinMarigin(screenPoint, in: dc) else { continue }
                
                let r = artist.starRadius(star, in: dc)
                dc.fillDot(at: screenPoint, radius: r, color: star.spectralClass.color)
            }
        }
    }
}




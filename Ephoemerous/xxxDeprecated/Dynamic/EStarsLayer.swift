import SwiftUI
import CoreLocation
import simd


struct EStarsLayer: EGridLayer {
    let artist = EArtist.shared
    private static let stars: [EStar] =
    StarDatabase.shared.workableStars .filter {
        ($0.magnitude < 6.5)
//        && ($0.constellation.isZodiacSign)
    }
    
    func draw(in dc: inout EGraphicContext) {
        
        for star in Self.stars {
            
            let (pRA, pDec) = EPrecession.precess(
                ra  : star.rightAscension,
                dec : star.declination,
                to  : dc.state.observationDate
            )
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.state.precessedSiderealOffset)
            
            if let projPoint = EProjection.project(Q, appState: dc.state) {
                
                let screenPoint = dc.toScreen(projPoint)
                
                guard artist.starPointFallsWithinMarigin(screenPoint, in: dc) else { continue }
                
                let r = artist.starRadius(star, in: dc)
                dc.fillDot(at: screenPoint, radius: r, color: star.spectralClass.color)
            }
        }
    }
}



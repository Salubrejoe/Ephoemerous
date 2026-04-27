import SwiftUI
import CoreLocation
import simd


struct EULStarsLayer: EGridLayer {
    @Environment(\.colorScheme) var colorScheme
    let artist = EArtist.shared
    func draw(in dc: inout EGraphicContext) {
        
        for star in dc.state.stars {
            
            let (pRA, pDec) = EPrecession.precess(
                ra  : star.rightAscension,
                dec : star.declination,
                to  : dc.state.observationDate
            )
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.state.precessedSiderealOffset)
            
            if let projPoint = EProjection.project(Q, appState: dc.state, mode: .userLocation) {
                
                let screenPoint = dc.toScreen(projPoint)
                
                guard artist.starPointFallsWithinMarigin(screenPoint, in: dc) else { continue }
                
                let r = artist.starRadius(star, in: dc)
                dc.fillDot(
                    at: screenPoint,
                    radius: r,
                    color: .black
                )
            }
        }
    }
}



import SwiftUI
import CoreLocation
import simd


struct EULStarsLayer: EGridLayer {
    let artist = EArtist.shared
    // TODO: Check - verify showStars guard is present; EULStarsLayer may be missing it unlike ENSStarsLayer
        func draw(in dc: inout EGraphicContext) {
        guard dc.state.showStars else { return }
        for star in dc.state.travelStars {
            
            let (pRA, pDec) = EPrecession.precess(
                ra  : star.rightAscension,
                dec : star.declination,
                to  : dc.state.renderedObservationDate
            )
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.state.localSiderealOffset)
            
            if let projPoint = EProjection.project(Q, appState: dc.state, mode: .userLocation) {
                
                let screenPoint = dc.toScreen(projPoint)
                
                guard artist.starPointFallsWithinMarigin(screenPoint, in: dc) else { continue }
                
                let r = artist.starRadius(star, in: dc)
                // Soft glow behind the star
                var glow = dc.ctx
                glow.addFilter(.blur(radius: r * AstroConstants.starGlowBlurRatio))
                glow.fill(
                    Path(ellipseIn: CGRect(x: screenPoint.x - r, y: screenPoint.y - r, width: r * 2, height: r * 2)),
                    with: .color(star.spectralClass.color.opacity(1))
                )
                
                dc.fillDot(
                    at: screenPoint,
                    radius: r,
                    color: star.spectralClass.color.opacity(0.65).exposureAdjust(.piHalf)
                )
            }
        }
    }
}



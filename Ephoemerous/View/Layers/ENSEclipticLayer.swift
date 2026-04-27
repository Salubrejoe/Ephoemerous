
import SwiftUI
import simd


struct ENSEclipticLayer: EGridLayer {
    let artist = EArtist.shared
    
    func draw(in dc: inout EGraphicContext) {
        let eclPts = EProjection.sampleEcliptic(
            appState: dc.state,
            mode: .northSouth
        )
        
        dc.strokeCurve(eclPts, color: artist.eclColor, width: artist.eclWidth)
    }
}



/*
 let eclipticPts = EProjection.sampleCurve(
 steps: 360,
 origin: proj.origin,
 plane: proj.plane
 ) { t in
 let λ = t * 2 * .pi
 let β = 0.0
 
 // Ecliptic Cartesian
 var e = SIMD3(
 cos(β) * cos(λ),
 cos(β) * sin(λ),
 sin(β)
 )
 
 // Rotate to equatorial by ε about x-axis
 e.rotateAboutXAxis(by: ε)
 
 // Rotate by sidereal angle about z-axis
 e.rotateAboutZAxis(by: θ)
 
 return e
 }
 */

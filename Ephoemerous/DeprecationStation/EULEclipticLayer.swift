import SwiftUI
import simd


struct EULEclipticLayer: EGridLayer {
    let artist = EArtist.shared
    
    func draw(in dc: inout EGraphicContext) {
        
        let eclPts = EProjection.sampleEcliptic(appState: dc.state, mode: .userLocation)
        dc.strokeCurve(eclPts, color: artist.eclColor, width: artist.eclWidth)
    }
}



/*
 
 for betaDeg in stride(from: 20, through: 1, by: -5) {
 let β = Double(betaDeg) * .pi / 180.0
 //            let label = betaDeg == 0 ? "0°" : (betaDeg > 0 ? "-\(betaDeg)°" : "\(betaDeg)°")
 let label = ""
 
 // Full 360° sweep in ecliptic longitude (λ)
 let pts = EPHProjection.sampleCurve(steps: 360, origin: O, plane: P) { t in
 let λ = t * 2 * .pi
 let cb = cos(β), sb = sin(β)
 let cl = cos(λ), sl = sin(λ)
 let xe = cb * cl
 let ye = cb * sl
 let ze = sb
 let yq = ye * cos(ε) - ze * sin(ε)
 let zq = ye * sin(ε) + ze * cos(ε)
 let xq = xe
 return SIMD3(xq * c - yq * s, xq * s + yq * c, zq)
 }
 dc.strokeCurve(pts, color: .primary.opacity(0.5), width: 0.5)
 
 // Try λ = 0° / 90° / 180° / 270° — use first position that lands on screen
 for i in 0..<4 {
 let λ = Double(i) * .pi / 2.0
 let cb = cos(β), sb = sin(β)
 let cl = cos(λ), sl = sin(λ)
 let xe = cb * cl
 let ye = cb * sl
 let ze = sb
 let yq = ye * cos(ε) - ze * sin(ε)
 let zq = ye * sin(ε) + ze * cos(ε)
 let xq = xe
 let rot = SIMD3(xq * c - yq * s, xq * s + yq * c, zq)
 guard let proj = EPHProjection.project(rot, origin: O, plane: P) else { continue }
 let sc = dc.toScreen(proj)
 guard dc.onScreen(sc, margin: 20) else { continue }
 dc.gridLabel(at: CGPoint(x: sc.x + 5, y: sc.y), text: label)
 break
 }
 }
 */

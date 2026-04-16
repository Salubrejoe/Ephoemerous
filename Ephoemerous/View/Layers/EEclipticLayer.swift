import SwiftUI
import simd



struct EEclipticLayer: EGridLayer {
    
    func draw(in dc: inout EGraphicContext) {
        let O = dc.state.originVector
        let P = dc.state.planeVector
        let θ = -dc.state.siderealOffset
        let (c, s) = (cos(θ), sin(θ))
        let ε = 23.43928 * .pi / 180.0   // obliquity of the ecliptic
        
        // Ecliptic (β = 0)
        let eclipticPts = EProjection.sampleCurve(steps: 360, origin: O, plane: P) { t in
            let λ = t * 2 * .pi
            let β = 0.0
            let cb = cos(β), sb = sin(β)
            let cl = cos(λ), sl = sin(λ)
            // Ecliptic Cartesian
            let xe = cb * cl
            let ye = cb * sl
            let ze = sb
            // Rotate to equatorial by ε about x-axis
            let yq = ye * cos(ε) - ze * sin(ε)
            let zq = ye * sin(ε) + ze * cos(ε)
            let xq = xe
            // Rotate by sidereal angle about z-axis
            return SIMD3(xq * c - yq * s, xq * s + yq * c, zq)
        }
        dc.strokeCurve(eclipticPts, color: .yellow.opacity(0.5), width: 4)
        
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

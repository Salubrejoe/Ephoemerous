import SwiftUI
import simd
/*
 
 
 
 struct EPHEclipticLayer: EGridLayer {
 
 func draw(in dc: inout EGraphicContext) {
 let O = dc.state.originVector
 let P = dc.state.planeVector
 let θ = -dc.state.siderealOffset
 let (c, s) = (cos(θ), sin(θ))
 
 let pts = EProjection.sampleCurve(steps: 360, origin: O, plane: P) { t in
 let lam = t * 2 * Double.pi
 let p   = EProjection.eclipticPoint(lambda: lam)
 return SIMD3(p.x * c - p.y * s, p.x * s + p.y * c, p.z)
 }
 dc.strokeCurve(pts, color: .yellow.opacity(0.4), width: 3)
 }
 }
 
 
 */


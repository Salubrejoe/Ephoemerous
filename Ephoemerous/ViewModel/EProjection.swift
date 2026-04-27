import SwiftUI
import simd


enum EProjection {
    
    enum ProjectionFrame {
        case northSouth
        case userLocation
    }
    
    static var obliquity: Angle { AstroConstants.obliquity }
    
    static func project(_ Q      : SIMD3<Double>,
                        origin  O: SIMD3<Double>,
                        plane   P: SIMD3<Double>) -> CGPoint? {

        let PdotO = simd_dot(P, O)
        let PdotQ = simd_dot(P, Q)
        let denom = PdotQ - PdotO
        guard abs(denom) > 1e-10 else { return nil }
        let t = (1.0 - PdotO) / denom
        guard t > 0 else { return nil }
        let intersection = O + t * (Q - O)
        let delta = intersection - P
        let (e1, e2) = P.baseVectors()
        //        let (e1, e2) = tangentBasis(P)
        let u = simd_dot(delta, e1)
        let v = simd_dot(delta, e2)
        return CGPoint(x: v, y: u)
    }
    
    static func project(_ Q     : SIMD3<Double>,
                        appState: EAppState,
                        mode: ProjectionFrame) -> CGPoint? {
        if mode == .northSouth {
            project(
                Q,
                origin: .north,
                plane: .south
            )
        } else {
            project(
                Q,
                origin: appState.originVector,
                plane: appState.planeVector
            )
        }
    }
 
    
    
    static func sampleCurve(steps: Int = 360,
                            appState: EAppState,
                            mode: ProjectionFrame,
                            point: (Double) -> SIMD3<Double>) -> [CGPoint?] {
        (0...steps).map { i in
            project(
                point(Double(i) / Double(steps)),
                appState: appState,
                mode: mode
            )
        }
    }
    
    static func sampleEcliptic(
        steps: Int = 360,
        appState: EAppState,
        mode: ProjectionFrame
    ) -> [CGPoint?] {
        
        // Ecliptic -> β = 0.0
        (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let Q = EPrecession.eclipticVector(
                atStep: t,
                siderealOffset: appState.precessedSiderealOffset
            )
            return EProjection.project(
                Q,
                appState: appState,
                mode: mode
            )
        }
    }
}








/*
 static func tangentBasis(_ P: Vector🏹) -> (e1: Vector🏹, e2: Vector🏹) {
 let north = Vector🏹(0, 0, 1)
 var e1 = simd_cross(simd_cross(P, north), P)
 if simd_length_squared(e1) < 1e-10 { e1 = Vector🏹(1, 0, 0) }
 e1 = simd_normalize(e1)
 let e2 = simd_normalize(simd_cross(P, e1))
 return (e1, e2)
 }
 
 
 static func spherePoint(lat: Radians, lon: Radians) -> SIMD3<Double> {
 SIMD3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
 }
 
 static func eclipticPoint(lambda: Angle) -> Vector🏹 {
 SIMD3(
 cos(lambda.radians),
 sin(lambda.radians) * cos(obliquity.radians),
 sin(lambda.radians) * sin(obliquity.radians)
 )
 }
 */

/*
 
 static func sampleEcliptic(steps: Int = 360,
 siderealOffset: Angle,
 origin O: Vector🏹,
 plane  P: Vector🏹) -> PointSet {
 
 // Ecliptic -> β = 0.0
 (0...steps).map { i in
 let t = Double(i) / Double(steps)
 let λ = t * 2 * .pi
 let β = 0.0
 let θ = siderealOffset.radians
 
 let ε = obliquity.radians   // obliquity of the ecliptic
 let cb = cos(β), sb = sin(β)
 let cl = cos(λ), sl = sin(λ)
 let xe = cb * cl
 let ye = cb * sl
 let ze = sb
 let yq = ye * cos(ε) - ze * sin(ε)
 let zq = ye * sin(ε) + ze * cos(ε)
 let xq = xe
 let Q = SIMD3(
 xq * cos(θ) - yq * sin(θ),
 xq * sin(θ) + yq * cos(θ),
 zq
 )
 
 return project(
 Q,
 origin: O,
 plane: P
 )
 }
 }
 */

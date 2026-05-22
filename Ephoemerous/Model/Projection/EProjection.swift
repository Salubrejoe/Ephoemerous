import SwiftUI
import simd


enum EProjection {

    enum ProjectionFrame {
        case northSouth
        case userLocation
    }

    /// Per-frame snapshot of the observer geometry the projection needs.
    /// `originVector` / `planeVector` / `nsOriginVector` are computed
    /// `@Observable` properties on `EAppState`; resolving them once per
    /// frame (see `EGraphicContext`) and threading this value keeps the
    /// per-point `project()` calls — 10k+ a frame — off the observation
    /// graph entirely.
    struct Viewpoint {
        let originVector:   SIMD3<Double>
        let planeVector:    SIMD3<Double>
        let nsOriginVector: SIMD3<Double>
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
        var (e1, e2) = P.baseVectors()
//        // Pin e2 so it always points toward the same celestial hemisphere as O,
//        // preventing a sign flip when P crosses low latitudes during a drag.
//        if simd_dot(e2, O) < 0 { e2 = -e2 }
        let u = simd_dot(delta, e1)
        let v = simd_dot(delta, e2)
        return CGPoint(x: v, y: u)
    }
    
    static func project(_ Q     : SIMD3<Double>,
                        viewpoint: Viewpoint,
                        mode: ProjectionFrame,
                        negateUserLocation: Bool = true) -> CGPoint? {
        if mode == .northSouth {
            // NS origin is dynamic so the two-finger drag can tilt the
            // celestial frame in step with the UL horizon. The plane
            // stays fixed at `.south` — only the origin is displaced.
            // At rest, `nsOriginVector` resolves to `.north`, so this
            // reduces to the historical hardcoded behaviour.
            return project(
                Q,
                origin: viewpoint.nsOriginVector,
                plane:  .south
            )
        } else {
            // No -Q sign flip. With the projection source = observer zenith
            // and plane tangent at the nadir, projecting Q directly gives an
            // "external observer at zenith looking down" view. At observer
            // = NP this collapses to the same math as the NS branch, so the
            // clock↔travel slerp is geometrically continuous and ends with
            // Polaris off-screen (the user's "looking south from NP through
            // the horizon" view).
            guard let p = project(
                Q,
                origin: viewpoint.originVector,
                plane: viewpoint.planeVector
            ) else { return nil }
            // Manual π rotation: `baseVectors()`'s singular fallback at
            // P=(0,0,-1) (used by NS) is opposite its continuous limit at
            // any non-pole observer (used by UL). Negating the UL output
            // realigns the two bases on screen so the sun, moon, stars,
            // constellations, ecliptic — and the RA/Dec EarthGrid —
            // share one celestial frame: drag the observer and they all
            // track together. Only HorizonLayer opts out via
            // `negateUserLocation: false`, because the horizon is the
            // observer's *local* frame and is meant to slide against the
            // sky, not with it.
            return negateUserLocation ? CGPoint(x: -p.x, y: -p.y) : p
        }
    }
 
    
    
    static func sampleCurve(steps: Int = 360,
                            viewpoint: Viewpoint,
                            mode: ProjectionFrame,
                            negateUserLocation: Bool = true,
                            point: (Double) -> SIMD3<Double>) -> [CGPoint?] {
        (0...steps).map { i in
            project(
                point(Double(i) / Double(steps)),
                viewpoint:          viewpoint,
                mode:               mode,
                negateUserLocation: negateUserLocation
            )
        }
    }

    static func sampleEcliptic(
        steps: Int = 360,
        viewpoint: Viewpoint,
        mode: ProjectionFrame,
        siderealOffset: Angle
    ) -> [CGPoint?] {

        // Ecliptic -> β = 0.0
        (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let Q = EPrecession.eclipticVector(
                atStep: t,
                siderealOffset: siderealOffset
            )
            return EProjection.project(
                Q,
                viewpoint: viewpoint,
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

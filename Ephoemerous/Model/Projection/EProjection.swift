import SwiftUI
import simd
import LoreKit

/// The two sky perspectives. They differ in what's ANCHORED and what MOVES:
///
/// - `northIn`  — the observer's frame: the HORIZON is a fixed circle at
///   screen centre and the sky slides under it as location/time change.
///   Celestial north sits IN (near centre, inside the horizon, for a
///   northern observer).
/// - `northOut` — the celestial frame: the SKY is fixed (centred on the
///   South celestial pole, RA as radial spokes, Dec as concentric rings)
///   and the HORIZON is the thing that moves — latitude slides it (a circle
///   at the poles, a straight line at the equator). Celestial north is flung
///   OUT to infinity, the visible sky OUTSIDE the horizon.
enum SkyPerspective: Equatable {
    case northIn
    case northOut
}


enum EProjection {

    /// Per-frame snapshot of the observer geometry the projection needs.
    /// `originVector` / `planeVector` are computed `@Observable`
    /// properties on `EAppState`; resolving them once per frame (see
    /// `EGraphicContext`) and threading this value keeps the per-point
    /// `project()` calls — 10k+ a frame — off the observation graph
    /// entirely.
    ///
    /// `originVector` is the observer's zenith direction (in the
    /// sidereally-rotated equatorial frame the projection runs in);
    /// `planeVector` is the antipodal nadir.
    struct Viewpoint {
        let originVector: SIMD3<Double>
        let planeVector:  SIMD3<Double>
        /// Which perspective to project in — see `SkyPerspective`. Defaults
        /// to the observer-centred (`.northIn`) view.
        var perspective: SkyPerspective = .northIn

        /// Returns a 3-D point on the observer's local sky at the given
        /// altitude above the horizon, parametrised by `t ∈ 0...1`
        /// around the small-circle of constant altitude.
        ///
        /// - `altitude = 0` traces the local horizon great circle
        ///   (perpendicular to the zenith) — a circle of radius 2 in
        ///   projection units, centred at screen centre.
        /// - `altitude < 0` traces a small circle below the horizon
        ///   (twilight zones).
        /// - `altitude > 0` traces a parallel of constant altitude
        ///   above the horizon (zenith → altitude = π/2 collapses to
        ///   the zenith point).
        ///
        /// Built on `baseVectors(zenith)` so the parametrisation uses
        /// the same orthonormal basis the projection itself uses — the
        /// stereographic image of any altitude small-circle is
        /// guaranteed to be a true circle on screen, centred on the
        /// projection origin.
        func skyPoint(altitude: Angle, at t: Double) -> SIMD3<Double> {
            let (e1, e2) = originVector.baseVectors()
            let phi      = t * 2.0 * Double.pi
            let sa       = sin(altitude.radians)
            let ca       = cos(altitude.radians)
            return sa * originVector
                 + ca * (cos(phi) * e1 + sin(phi) * e2)
        }

        /// As `skyPoint(altitude:at:)`, but addressed directly by horizon
        /// azimuth (clockwise from due north: N = 0, E = π/2) rather than
        /// the circle parameter `t`. Shares the same `baseVectors` basis —
        /// `e1` is celestial north, `e2` celestial west — so a direction
        /// fed through here lands on exactly the same sky the stars
        /// project onto. The device-aim blob rides this so it sits on the
        /// real stars the phone points at.
        func skyPoint(azimuth: Double, altitude: Double) -> SIMD3<Double> {
            let (e1, e2) = originVector.baseVectors()
            let sa       = sin(altitude)
            let ca       = cos(altitude)
            // Azimuth clockwise from north; east = −west = −e2.
            return sa * originVector
                 + ca * (cos(azimuth) * e1 - sin(azimuth) * e2)
        }
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
    
    /// Observer-centred stereographic projection: source = the observer's
    /// nadir, plane = the observer's zenith. Visible sky (alt > 0) maps
    /// INSIDE a horizon circle of radius 2, the zenith lands at screen
    /// centre, below-horizon stars project outside / to infinity.
    ///
    /// Orientation: `baseVectors(zenith)` naturally produces a basis
    /// where `e1` points celestial north and `e2` points celestial
    /// west, so the unnegated screen output puts north at the top —
    /// the planetarium convention. The observer-latitude clamp
    /// (±89.999°, see `setOrigin`) keeps us off `baseVectors`'s
    /// singular fallback, so the basis stays continuous everywhere.
    ///
    /// Clock mode is "this projection with the observer pinned at
    /// lat 90°" — zenith collapses onto the celestial north pole, the
    /// horizon onto the celestial equator. No separate code path.
    static func project(_ Q     : SIMD3<Double>,
                        viewpoint: Viewpoint) -> CGPoint? {
        switch viewpoint.perspective {
        case .northIn:
            // Observer frame: eye at the nadir, tangent plane at the zenith →
            // zenith centred, the horizon a fixed radius-2 circle, the sky
            // moving under it.
            return project(
                Q,
                origin: viewpoint.planeVector,    // observer's nadir
                plane:  viewpoint.originVector    // observer's zenith
            )
        case .northOut:
            // Celestial frame: eye at the celestial NORTH pole, tangent at
            // the SOUTH pole. These are FIXED — the polar axis is invariant
            // under the sidereal rotation the callers bake into `Q` — so the
            // sky wheels around the SCP with time while location leaves the
            // stars untouched (only the separately-drawn horizon moves). SCP
            // at centre, north to infinity, visible sky outside the horizon.
            return project(
                Q,
                origin: SIMD3(0, 0,  1),          // celestial north pole
                plane:  SIMD3(0, 0, -1)           // celestial south pole
            )
        }
    }
 
    
    
    static func sampleCurve(steps: Int = 360,
                            viewpoint: Viewpoint,
                            point: (Double) -> SIMD3<Double>) -> [CGPoint?] {
        (0...steps).map { i in
            project(
                point(Double(i) / Double(steps)),
                viewpoint: viewpoint
            )
        }
    }

    static func sampleEcliptic(
        steps: Int = 360,
        viewpoint: Viewpoint,
        siderealOffset: Angle
    ) -> [CGPoint?] {

        // Ecliptic -> β = 0.0
        (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let Q = EPrecession.eclipticVector(
                atStep: t,
                siderealOffset: siderealOffset
            )
            return EProjection.project(Q, viewpoint: viewpoint)
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

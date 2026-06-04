//
//  EProjectionTests.swift
//  EphoemerousTests
//
//  Pure-math tests for the observer-centred stereographic projection.
//  No app state, no I/O — just the geometry the whole canvas trusts.
//

import Testing
import Foundation
import simd
import SwiftUI
@testable import Ephoemerous

struct EProjectionTests {

    /// A viewpoint built from an arbitrary unit zenith. Default is a
    /// non-polar direction (≈ latitude 53°) so we stay clear of the
    /// `baseVectors` singularity at ±z. `planeVector` is the antipodal
    /// nadir, as `EAppState` produces it.
    private func viewpoint(
        zenith v: SIMD3<Double> = simd_normalize(SIMD3(0.6, 0.0, 0.8))
    ) -> EProjection.Viewpoint {
        EProjection.Viewpoint(originVector: v, planeVector: -v)
    }

    private func radius(_ p: CGPoint) -> Double {
        (p.x * p.x + p.y * p.y).squareRoot()
    }

    // MARK: - Anchors

    /// The observer's zenith projects to the screen origin (0, 0).
    @Test func zenithProjectsToOrigin() throws {
        let vp = viewpoint()
        let p  = try #require(EProjection.project(vp.originVector, viewpoint: vp))
        #expect(abs(p.x) < 1e-9)
        #expect(abs(p.y) < 1e-9)
    }

    /// The nadir is directly behind the projection — it has no image.
    @Test func nadirProjectsToNil() {
        let vp = viewpoint()
        #expect(EProjection.project(vp.planeVector, viewpoint: vp) == nil)
    }

    /// The horizon great circle (altitude 0) images to a circle of
    /// radius 2, all the way around.
    @Test func horizonPointsHaveRadiusTwo() throws {
        let vp = viewpoint()
        for i in 0..<12 {
            let t = Double(i) / 12.0
            let q = vp.skyPoint(altitude: .zero, at: t)
            let p = try #require(EProjection.project(q, viewpoint: vp))
            #expect(abs(radius(p) - 2.0) < 1e-6)
        }
    }

    /// Projected radius follows the stereographic law
    /// ρ = 2·cos(alt) / (1 + sin(alt)) — 2 at the horizon, 0 at the zenith.
    @Test func stereographicRadiusMatchesFormula() throws {
        let vp = viewpoint()
        for deg in [0.0, 15, 30, 45, 60, 80] {
            let a = Angle.degrees(deg)
            let q = vp.skyPoint(altitude: a, at: 0.0)
            let p = try #require(EProjection.project(q, viewpoint: vp))
            let expected = 2 * cos(a.radians) / (1 + sin(a.radians))
            #expect(abs(radius(p) - expected) < 1e-6)
        }
    }

    /// Radius is strictly monotonic in altitude: the higher a point sits,
    /// the closer to centre it lands.
    @Test func radiusDecreasesWithAltitude() throws {
        let vp = viewpoint()
        var last = Double.infinity
        for deg in stride(from: 0.0, through: 89.0, by: 10.0) {
            let q = vp.skyPoint(altitude: .degrees(deg), at: 0.0)
            let p = try #require(EProjection.project(q, viewpoint: vp))
            let r = radius(p)
            #expect(r < last)
            last = r
        }
    }
}

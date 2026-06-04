//
//  EPrecessionTests.swift
//  EphoemerousTests
//
//  Pure-math tests for the equatorial unit vector + IAU precession.
//  Deterministic: equatorialVector takes no date; precession is anchored
//  to fixed UTC dates.
//

import Testing
import Foundation
import simd
import SwiftUI
@testable import Ephoemerous

struct EPrecessionTests {

    private func vec(_ ra: Angle, _ dec: Angle) -> SIMD3<Double> {
        EPrecession.equatorialVector(ra: ra, dec: dec)
    }

    /// Angle (radians) between two unit vectors.
    private func angle(_ u: SIMD3<Double>, _ v: SIMD3<Double>) -> Double {
        acos(max(-1, min(1, simd_dot(u, v))))
    }

    private func utcDate(year: Int, month: Int = 1, day: Int = 1, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = 0; c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    // MARK: - equatorialVector

    /// Every (RA, Dec) maps to a unit vector.
    @Test func equatorialVectorIsUnitLength() {
        for raDeg in stride(from: 0.0, to: 360, by: 37) {
            for decDeg in stride(from: -80.0, through: 80, by: 20) {
                let v = vec(.degrees(raDeg), .degrees(decDeg))
                #expect(abs(simd_length(v) - 1) < 1e-12)
            }
        }
    }

    /// The cardinal directions land on the expected axes.
    @Test func equatorialVectorCorners() {
        func near(_ v: SIMD3<Double>, _ e: SIMD3<Double>) -> Bool {
            simd_length(v - e) < 1e-12
        }
        #expect(near(vec(.degrees(0),   .degrees(0)),   SIMD3( 1,  0,  0)))
        #expect(near(vec(.degrees(90),  .degrees(0)),   SIMD3( 0,  1,  0)))
        #expect(near(vec(.degrees(180), .degrees(0)),   SIMD3(-1,  0,  0)))
        #expect(near(vec(.degrees(270), .degrees(0)),   SIMD3( 0, -1,  0)))
        #expect(near(vec(.degrees(0),   .degrees(90)),  SIMD3( 0,  0,  1)))
        #expect(near(vec(.degrees(0),   .degrees(-90)), SIMD3( 0,  0, -1)))
    }

    // MARK: - precess

    /// At the J2000 epoch the precession matrix is the identity, so
    /// coordinates come back unchanged.
    @Test func precessIsIdentityAtJ2000() {
        let ra  = Angle.degrees(83.0)
        let dec = Angle.degrees(7.0)
        let (r, d) = EPrecession.precess(ra: ra, dec: dec, to: EPrecession.j2000)
        #expect(abs(r.degrees - ra.degrees) < 1e-9)
        #expect(abs(d.degrees - dec.degrees) < 1e-9)
    }

    /// Over a century the same coordinates shift appreciably — proof the
    /// precession is actually applied (not silently identity).
    @Test func precessShiftsForFarDate() {
        let ra  = Angle.degrees(83.0)
        let dec = Angle.degrees(7.0)
        let (r, d) = EPrecession.precess(ra: ra, dec: dec, to: utcDate(year: 2125))
        let moved = abs(r.degrees - ra.degrees) + abs(d.degrees - dec.degrees)
        #expect(moved > 0.1)
    }

    /// Precession is a rigid rotation of the sky, so the angular
    /// separation between two stars is invariant under it.
    @Test func precessPreservesAngularSeparation() {
        let future = utcDate(year: 2125)
        let a = (ra: Angle.degrees(83),  dec: Angle.degrees(7))    // ~Betelgeuse
        let b = (ra: Angle.degrees(101), dec: Angle.degrees(-16))  // ~Sirius

        let before = angle(vec(a.ra, a.dec), vec(b.ra, b.dec))
        let pa = EPrecession.precess(ra: a.ra, dec: a.dec, to: future)
        let pb = EPrecession.precess(ra: b.ra, dec: b.dec, to: future)
        let after = angle(vec(pa.ra, pa.dec), vec(pb.ra, pb.dec))

        #expect(abs(before - after) < 1e-6)
    }

    /// The precessed coordinates still describe a unit vector (no drift
    /// out of the clamp in `asin`).
    @Test func precessedVectorStaysUnit() {
        let (r, d) = EPrecession.precess(ra: .degrees(83), dec: .degrees(7),
                                         to: utcDate(year: 2125))
        #expect(abs(simd_length(vec(r, d)) - 1) < 1e-12)
    }
}

//
//  MagnitudeCapTests.swift
//  EphoemerousTests
//
//  The zoom → visible-magnitude curve: two linear segments through
//  floor / default / ceiling anchors, clamped at the ends.
//

import Testing
import Foundation
@testable import Ephoemerous

struct MagnitudeCapTests {

    // init() is trivial (just origin/plane defaults) — safe in a test.
    private let state = EAppState()

    @Test func clampsAtFloor() {
        #expect(abs(state.magnitudeCap(forScale: 25) - 4.5) < 1e-9)   // floor scale
        #expect(abs(state.magnitudeCap(forScale:  5) - 4.5) < 1e-9)   // below floor
    }

    @Test func clampsAtCeiling() {
        let ceil = AstroConstants.maximumScale
        #expect(abs(state.magnitudeCap(forScale: ceil)        - 8.0) < 1e-9)
        #expect(abs(state.magnitudeCap(forScale: ceil + 1000) - 8.0) < 1e-9)
    }

    @Test func defaultScaleIsNakedEye() {
        #expect(abs(state.magnitudeCap(forScale: AstroConstants.defaultScale) - 6.2) < 1e-9)
    }

    @Test func monotonicNonDecreasing() {
        var last = -Double.infinity
        for s in stride(from: 10.0, through: AstroConstants.maximumScale + 100, by: 50) {
            let cap = state.magnitudeCap(forScale: s)
            #expect(cap >= last)
            last = cap
        }
    }

    /// Midpoint of the lower (floor → default) segment is the linear blend.
    @Test func firstSegmentMidpointIsLinear() {
        let mid = (25.0 + AstroConstants.defaultScale) / 2
        let t   = (mid - 25.0) / (AstroConstants.defaultScale - 25.0)   // 0.5
        let expected = 4.5 + (6.2 - 4.5) * t
        #expect(abs(state.magnitudeCap(forScale: mid) - expected) < 1e-9)
    }
}

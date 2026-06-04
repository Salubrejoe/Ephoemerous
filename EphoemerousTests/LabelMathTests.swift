//
//  LabelMathTests.swift
//  EphoemerousTests
//
//  Pure easing math for POI label promotion + zoom-tier reveal.
//

import Testing
import Foundation
import SwiftUI
@testable import Ephoemerous

struct LabelMathTests {

    private let artist = EArtist.shared

    // MARK: - poiSelectProgress (rise = 0.3s, smoothstep)

    @Test func poiSelectProgressEndpoints() {
        #expect(abs(artist.poiSelectProgress(from: 0, to: 1, elapsed: 0)   - 0) < 1e-12)
        #expect(abs(artist.poiSelectProgress(from: 0, to: 1, elapsed: 0.3) - 1) < 1e-12)
    }

    @Test func poiSelectProgressClamps() {
        #expect(abs(artist.poiSelectProgress(from: 0, to: 1, elapsed: -1) - 0) < 1e-12)
        #expect(abs(artist.poiSelectProgress(from: 0, to: 1, elapsed:  5) - 1) < 1e-12)
    }

    /// Halfway through the rise, smoothstep gives the halfway value.
    @Test func poiSelectProgressMidpoint() {
        let half = artist.poiSelectProgress(from: 0, to: 1, elapsed: 0.15)
        #expect(abs(half - 0.5) < 1e-9)
    }

    // MARK: - labelTierProgress (smoothstep ramp centred on the threshold)

    @Test func labelTierProgressBelowAndAbove() {
        #expect(abs(artist.labelTierProgress(scale:  50, threshold: 100) - 0) < 1e-12)
        #expect(abs(artist.labelTierProgress(scale: 200, threshold: 100) - 1) < 1e-12)
    }

    @Test func labelTierProgressHalfAtThreshold() {
        #expect(abs(artist.labelTierProgress(scale: 100, threshold: 100) - 0.5) < 1e-9)
    }

    /// A non-positive threshold means "always on" (sun / moon badge).
    @Test func labelTierProgressAlwaysOnForNonPositiveThreshold() {
        #expect(abs(artist.labelTierProgress(scale: 0, threshold:   0) - 1) < 1e-12)
        #expect(abs(artist.labelTierProgress(scale: 0, threshold: -10) - 1) < 1e-12)
    }

    // MARK: - labelTierScale (floor 0.82 → 1.0)

    @Test func labelTierScaleEndpointsAndMid() {
        #expect(abs(artist.labelTierScale(0)   - 0.82) < 1e-9)
        #expect(abs(artist.labelTierScale(1)   - 1.00) < 1e-9)
        #expect(abs(artist.labelTierScale(0.5) - 0.91) < 1e-9)
    }
}

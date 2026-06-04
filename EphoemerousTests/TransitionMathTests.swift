//
//  TransitionMathTests.swift
//  EphoemerousTests
//
//  Pure interpolation math for the camera + rotation transitions.
//

import Testing
import Foundation
import SwiftUI
@testable import Ephoemerous

struct TransitionMathTests {

    // MARK: - bounceEase

    @Test func bounceEaseEndpoints() {
        #expect(abs(EPresetTransition.bounceEase(0) - 0) < 1e-12)
        #expect(abs(EPresetTransition.bounceEase(1) - 1) < 1e-12)
    }

    @Test func bounceEaseClampsOutOfRange() {
        #expect(abs(EPresetTransition.bounceEase(-0.5) - 0) < 1e-12)
        #expect(abs(EPresetTransition.bounceEase(1.5)  - 1) < 1e-12)
    }

    /// The "bounce": the curve eases *past* 1 before settling — that
    /// overshoot is what gives the camera/compass its springy feel.
    @Test func bounceEaseOvershootsBeforeSettling() {
        #expect(EPresetTransition.bounceEase(0.9) > 1.0)
    }

    // MARK: - EPresetTransition

    private func preset() -> EPresetTransition {
        EPresetTransition(fromScale:  100, fromOffset: CGPoint(x: 10, y: 20),
                          toScale:    200, toOffset:   CGPoint(x: 30, y: 40),
                          startTime:  0,   duration:   1)
    }

    @Test func presetInterpolatesEndpoints() {
        let t = preset()
        #expect(abs(t.interpolatedScale(at: 0) - 100) < 1e-9)
        #expect(abs(t.interpolatedScale(at: 1) - 200) < 1e-9)

        let o0 = t.interpolatedOffset(at: 0)
        #expect(abs(o0.x - 10) < 1e-9)
        #expect(abs(o0.y - 20) < 1e-9)

        let o1 = t.interpolatedOffset(at: 1)
        #expect(abs(o1.x - 30) < 1e-9)
        #expect(abs(o1.y - 40) < 1e-9)
    }

    @Test func presetIsFinished() {
        let t = preset()
        #expect(!t.isFinished(at: 0.99))
        #expect(t.isFinished(at: 1.0))
        #expect(t.isFinished(at: 2.0))
    }

    // MARK: - ERotationTransition

    private func rotation() -> ERotationTransition {
        ERotationTransition(from: .degrees(90), to: .degrees(0),
                            startTime: 0, duration: 1)
    }

    @Test func rotationInterpolatesEndpoints() {
        let t = rotation()
        #expect(abs(t.interpolated(at: 0).degrees - 90) < 1e-9)
        #expect(abs(t.interpolated(at: 1).degrees -  0) < 1e-9)
    }

    @Test func rotationIsFinished() {
        let t = rotation()
        #expect(!t.isFinished(at: 0.5))
        #expect(t.isFinished(at: 1.0))
    }
}

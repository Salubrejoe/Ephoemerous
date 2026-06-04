//
//  GestureMathTests.swift
//  EphoemerousTests
//
//  The camera-correctness layer: scale clamping and the screen⇄sky
//  inverse round-trips that make pan / pinch track the finger — including
//  when the canvas is rotated.
//

import Testing
import Foundation
import SwiftUI
@testable import Ephoemerous

struct GestureMathTests {

    /// A state fixture with a non-zero canvas and explicit camera. init()
    /// is trivial; with no active transition rendered == committed, so
    /// `toScreenPoint` and the coordinator's inverse use the same numbers.
    private func makeState(
        size:     CGSize  = CGSize(width: 400, height: 800),
        scale:    Double  = 215,
        offset:   CGPoint = .zero,
        rotation: Angle   = .zero
    ) -> EAppState {
        let s = EAppState()
        s.canvasSize     = size
        s.scale          = scale
        s.offset         = offset
        s.canvasRotation = rotation
        return s
    }

    // MARK: - clampScale

    @Test func clampScalePassesThroughInRange() {
        let g = CelestialGestureCoordinator()
        #expect(g.clampScale(200, state: makeState()) == 200)
    }

    @Test func clampScaleClampsToBounds() {
        let g = CelestialGestureCoordinator()
        let s = makeState()
        #expect(g.clampScale(1,      state: s) == g.minimumScale)
        #expect(g.clampScale(999_999, state: s) == g.maximumScale)
    }

    @Test func clampScaleNaNFallsToMinimum() {
        let g = CelestialGestureCoordinator()
        #expect(g.clampScale(.nan, state: makeState()) == g.minimumScale)
    }

    // MARK: - skyPoint ∘ toScreenPoint == identity

    @Test func skyPointInvertsToScreen() {
        let g = CelestialGestureCoordinator()
        let s = makeState(offset: CGPoint(x: 30, y: -40))
        for p in samplePoints {
            let screen = s.toScreenPoint(p)
            let back   = g.skyPoint(under: screen, state: s)
            #expect(abs(back.x - p.x) < 1e-9)
            #expect(abs(back.y - p.y) < 1e-9)
        }
    }

    /// The same round-trip must hold with the canvas rotated — this is
    /// what guarantees pan/pinch still follow the finger under rotation.
    @Test func skyPointInvertsToScreenWhenRotated() {
        let g = CelestialGestureCoordinator()
        let s = makeState(offset: CGPoint(x: 30, y: -40), rotation: .degrees(35))
        for p in samplePoints {
            let screen = s.toScreenPoint(p)
            let back   = g.skyPoint(under: screen, state: s)
            #expect(abs(back.x - p.x) < 1e-9)
            #expect(abs(back.y - p.y) < 1e-9)
        }
    }

    // MARK: - screenPin pins a sky point under a target

    @Test func screenPinPlacesSkyUnderTarget() {
        pinHolds(rotation: .zero)
    }

    @Test func screenPinPlacesSkyUnderTargetWhenRotated() {
        pinHolds(rotation: .degrees(-50))
    }

    private func pinHolds(rotation: Angle) {
        let g = CelestialGestureCoordinator()
        let s = makeState(rotation: rotation)
        let sky    = CGPoint(x: 0.4, y: -0.6)
        let target = CGPoint(x: 120, y: 300)
        let scale  = 180.0
        // Pin: the offset that should land `sky` under `target` at `scale`.
        s.offset = g.screenPin(sky: sky, under: target, scale: scale, state: s)
        s.scale  = scale
        let landed = s.toScreenPoint(sky)
        #expect(abs(landed.x - target.x) < 1e-9)
        #expect(abs(landed.y - target.y) < 1e-9)
    }

    private let samplePoints: [CGPoint] = [
        CGPoint(x:  0.0, y:  0.0),
        CGPoint(x:  0.5, y: -0.3),
        CGPoint(x: -1.2, y:  0.8),
        CGPoint(x:  1.7, y:  1.1),
    ]
}

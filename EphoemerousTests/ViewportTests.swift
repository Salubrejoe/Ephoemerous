//
//  ViewportTests.swift
//  EphoemerousTests
//
//  Stateful (but side-effect-free) viewport math: offset clamping by zoom
//  zone, and the offsetToCenter round-trip that the focus/zoom camera
//  moves rely on.
//

import Testing
import Foundation
import SwiftUI
@testable import Ephoemerous

struct ViewportTests {

    private func makeState(
        size:   CGSize  = CGSize(width: 400, height: 800),
        scale:  Double  = 215,
        offset: CGPoint = .zero
    ) -> EAppState {
        let s = EAppState()
        s.canvasSize     = size
        s.scale          = scale
        s.offset         = offset
        s.canvasRotation = .zero
        return s
    }

    // MARK: - hardClampedOffset / viewportOffsetLimits

    /// At or above the anchor zoom, panning is free — the offset is
    /// returned untouched.
    @Test func freePanAtOrAboveDefaultScale() {
        let s = makeState()
        let o = CGPoint(x: 123, y: -456)
        #expect(s.hardClampedOffset(o, atScale: s.defaultScale + 10) == o)
    }

    /// Below the anchor zoom the rubber pulls fully home — any offset
    /// clamps to `defaultOffset`.
    @Test func clampsHomeBelowDefaultScale() {
        let s = makeState()
        let clamped = s.hardClampedOffset(CGPoint(x: 999, y: -999),
                                          atScale: s.defaultScale - 10)
        #expect(abs(clamped.x - s.defaultOffset.x) < 1e-9)
        #expect(abs(clamped.y - s.defaultOffset.y) < 1e-9)
    }

    @Test func clampIsIdempotent() {
        let s = makeState()
        let scale = s.defaultScale - 10
        let once  = s.hardClampedOffset(CGPoint(x: 999, y: -999), atScale: scale)
        let twice = s.hardClampedOffset(once, atScale: scale)
        #expect(once == twice)
    }

    /// No canvas yet → no limits (panning can't be bounded against an
    /// unknown viewport).
    @Test func offsetLimitsNilForZeroCanvas() {
        let s = EAppState()   // canvasSize defaults to .zero
        #expect(s.viewportOffsetLimits(forScale: 50) == nil)
    }

    // MARK: - offsetToCenter round-trip

    /// `offsetToCenter` returns the offset that lands a given on-screen
    /// point at a target after zooming — applying it should put the sky
    /// point exactly on the target.
    @Test func offsetToCenterPlacesPointAtTarget() {
        let s   = makeState(scale: 100, offset: CGPoint(x: 20, y: -10))
        let sky = CGPoint(x: 0.5, y: -0.4)

        let currentScreen = s.toScreenPoint(sky)
        let newScale = 250.0
        let target   = CGPoint(x: 150, y: 360)

        s.offset = s.offsetToCenter(screenPos: currentScreen, atScale: newScale,
                                    targetX: target.x, targetY: target.y)
        s.scale  = newScale

        let landed = s.toScreenPoint(sky)
        #expect(abs(landed.x - target.x) < 1e-6)
        #expect(abs(landed.y - target.y) < 1e-6)
    }
}

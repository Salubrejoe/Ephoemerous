import Testing
import CoreGraphics
import Foundation
@testable import LoreKit

// MARK: - Squircle
// The Lamé curve is unambiguous mathematically, so these tests pin a
// handful of analytic invariants rather than golden screenshots.

@Test func bulgeOfTwoIsCircle() {
    // r(θ) = (|cos|² + |sin|²)^(-1/2) = 1 for all θ.
    for t in stride(from: 0.0, through: 2 * .pi, by: 0.1) {
        let r = Squircle.lameRadius(angle: CGFloat(t), corners: 4, bulge: 2)
        #expect(abs(r - 1) < 1e-9)
    }
}

@Test func squircleFlatSidesUnit() {
    // 4-corner squircle: lameRadius = 1 at the cardinal axes (flat-side
    // midpoints) regardless of bulge.
    let cardinals: [CGFloat] = [0, .pi / 2, .pi, 3 * .pi / 2]
    for p in [CGFloat(2), 3, 4, 8] {
        for t in cardinals {
            let r = Squircle.lameRadius(angle: t, corners: 4, bulge: p)
            #expect(abs(r - 1) < 1e-9)
        }
    }
}

@Test func squircleCornersExceedUnit() {
    // 4-corner squircle: lameRadius > 1 on the diagonals (corners poke
    // out past the flat-side circle).
    let diagonals: [CGFloat] = [.pi / 4, 3 * .pi / 4, 5 * .pi / 4, 7 * .pi / 4]
    for t in diagonals {
        let r = Squircle.lameRadius(angle: t, corners: 4, bulge: 4)
        #expect(r > 1.0)
        #expect(r < 1.25)   // sanity ceiling; analytic value ≈ 1.189
    }
}

@Test func lameRadiusIsEven() {
    // r(-t) = r(t). Used by callers that compute screen-polar angle with
    // a sign convention different from the Squircle path's.
    for t in stride(from: 0.0, through: .pi, by: 0.13) {
        let a = Squircle.lameRadius(angle:  CGFloat(t), corners: 4, bulge: 4)
        let b = Squircle.lameRadius(angle: -CGFloat(t), corners: 4, bulge: 4)
        #expect(abs(a - b) < 1e-12)
    }
}

@Test func verticesFormClosedRing() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
    let pts  = Squircle(corners: 4, bulge: 4).vertices(in: rect, segments: 240)
    // First and last point coincide — the rim closes on itself.
    #expect(pts.count == 241)
    #expect(abs(pts.first!.x - pts.last!.x) < 1e-9)
    #expect(abs(pts.first!.y - pts.last!.y) < 1e-9)
}

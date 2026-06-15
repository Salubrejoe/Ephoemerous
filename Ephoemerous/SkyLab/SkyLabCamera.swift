import SwiftUI
import simd

// MARK: - SkyLabCamera
// Self-contained camera for the SkyLab rendering experiment — the proving
// ground for the "native overlays + Canvas, one shared parent transform"
// architecture (see SkyLabView).
//
// It holds the COMMITTED (resting) view transform and projects sky
// vectors to screen at that transform. During a gesture it stays FROZEN:
// the live pan / zoom is a single transform on the shared parent ZStack,
// so the Canvas grid and the SwiftUI overlays move as one and cannot
// desync — the whole point of the experiment. Astronomical inputs
// (viewpoint, sidereal time) are read from the shared `EAppState`; the
// transform (scale / offset) is the lab's own, independent of production.
struct SkyLabCamera: Equatable {
    var scale:  CGFloat
    var size:   CGSize

    var viewpoint: EProjection.Viewpoint
    var sidereal:  Angle

    static func == (l: SkyLabCamera, r: SkyLabCamera) -> Bool {
        l.scale == r.scale
            && l.size == r.size
            && l.sidereal == r.sidereal
            && l.viewpoint.originVector == r.viewpoint.originVector
            && l.viewpoint.planeVector == r.viewpoint.planeVector
    }

    /// Projection-unit point → screen pixel (N up, scale about centre
    /// ONLY). Pan deliberately lives OUTSIDE the camera, as a SwiftUI
    /// `.offset` applied outside the `.scaleEffect` (see SkyLabView): if
    /// the offset were baked in here, `.scaleEffect` would scale it and
    /// the gesture-commit would mismatch by `offset·(1−pinch)` — the
    /// "view travels on pinch release" bug. No canvas-rotation term yet;
    /// rotation joins once pan/zoom sync is proven.
    func screen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: size.width  / 2 + p.x * scale,
                y: size.height / 2 - p.y * scale)
    }

    /// Equatorial unit vector → screen, or `nil` when it projects behind
    /// the viewer. Same pipeline the production layers use:
    /// sidereally rotate → stereographic project → screen.
    func screen(equatorial Q: SIMD3<Double>) -> CGPoint? {
        let rotated = Q.sidereallyRotated(by: sidereal)
        guard let p = EProjection.project(rotated, viewpoint: viewpoint) else { return nil }
        return screen(p)
    }
}

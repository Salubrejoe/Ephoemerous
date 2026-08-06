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
// (viewpoint, sidereal time) are read from the shared `AppState`; the
// transform (scale / offset) is the lab's own, independent of production.
struct SkyCamera: Equatable {
    var scale:  CGFloat
    /// COMMITTED pan, baked into the projection so the Canvas draws
    /// centred on the view you're actually looking at — not on the
    /// zenith. Without this, at high zoom the panned-to region projects
    /// outside the (fixed, oversized) Canvas bounds and is CLIPPED → the
    /// grid / cartography vanish. The live gesture delta stays the
    /// parent transform; this is only the resting offset (see SkyLabView).
    var offset: CGSize
    /// COMMITTED canvas rotation, applied to the projection point about
    /// the centre (matching SwiftUI `.rotationEffect`, so the live
    /// parent rotation folds in seamlessly). Pan stays in screen space
    /// (added after rotation), so panning is unaffected by spin.
    var rotation: Angle = .zero
    var size:   CGSize

    var viewpoint: Projection.Viewpoint
    var sidereal:  Angle

    /// Where the observer is standing, recovered from the earth-fixed
    /// origin vector (its z IS sin φ). Saves threading a latitude down to
    /// every overlay that already holds a camera — the Moon's phase needs
    /// it, because the whole phase mirrors below the equator.
    var observerLatitude: Angle {
        .radians(asin(max(-1, min(1, viewpoint.originVector.z))))
    }

    static func == (l: SkyCamera, r: SkyCamera) -> Bool {
        l.scale == r.scale
            && l.offset == r.offset
            && l.rotation == r.rotation
            && l.size == r.size
            && l.sidereal == r.sidereal
            && l.viewpoint.originVector == r.viewpoint.originVector
            && l.viewpoint.planeVector == r.viewpoint.planeVector
            && l.viewpoint.morph == r.viewpoint.morph
    }

    /// Projection-unit point → screen pixel: scale about centre + the
    /// COMMITTED pan. Only the committed (resting) offset lives here so the
    /// Canvas draws centred on the view (no high-zoom clipping); the LIVE
    /// gesture delta is the parent transform, and the commit folds it in
    /// with the matching `offset·cMag` term — so there's still no
    /// pinch-release travel. No canvas-rotation term yet.
    func screen(_ p: CGPoint) -> CGPoint {
        // Scaled, y-flipped projection vector, rotated about the centre
        // (same operator as `.rotationEffect`), then panned in screen space.
        let vx = p.x * scale
        let vy = -p.y * scale
        let c  = CGFloat(cos(rotation.radians))
        let s  = CGFloat(sin(rotation.radians))
        return CGPoint(x: size.width  / 2 + (vx * c - vy * s) + offset.width,
                       y: size.height / 2 + (vx * s + vy * c) + offset.height)
    }

    /// Equatorial unit vector → screen, or `nil` when it projects behind
    /// the viewer. Same pipeline the production layers use:
    /// sidereally rotate → stereographic project → screen. Use for
    /// UN-rotated vectors (star `equatorialVector`, the Sun's ecliptic
    /// point).
    func screen(equatorial Q: SIMD3<Double>) -> CGPoint? {
        screen(rotatedEquatorial: Q.sidereallyRotated(by: sidereal))
    }

    /// Screen point for a vector that is ALREADY in the sidereally-rotated
    /// frame — the Moon / planet position helpers bake the rotation in
    /// (they take a `siderealOffset`), so re-rotating would double it.
    func screen(rotatedEquatorial Q: SIMD3<Double>) -> CGPoint? {
        guard let p = Projection.project(Q, viewpoint: viewpoint) else { return nil }
        return screen(p)
    }
}

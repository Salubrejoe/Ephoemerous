import SwiftUI
import simd

// MARK: - HorizonBlurOverlay
// Frosted glass over the ground BELOW the horizon — the visible sky stays
// sharp, the under-earth murk frosts over, and during the NorthIN↔NorthOUT
// morph the pane deforms with the horizon itself (circle → line → offset
// circle), which is the whole show.
//
// The trick that keeps it cheap: the stereographic image of the horizon
// great circle is a TRUE circle (or line) at EVERY morph value — the
// slerped eye is still a point on the sphere, and stereographic maps
// circles to circles. So instead of masking with a 240-point sampled
// path, we reconstruct the exact circle from three projected horizon
// points (plus the projected zenith to know which side is sky) and fill
// it with a backdrop material. ~a dozen projections a frame; the
// blur itself is the compositor's problem.
//
// Mounted INSIDE the shared parent transform, above the star canvases and
// below the native labels — the cartography stays sharp, the sky frosts.
struct HorizonBlurOverlay: View {

    let camera: SkyCamera

    var body: some View {
        HorizonRegion(camera: camera)
            // ▼ TWEAK the frost here — material = blur strength,
            //   opacity fades the whole effect ▼
            .fill(
                Color.black.opacity(0.45)
                , style: FillStyle(eoFill: true))
            .opacity(0.45)
            .allowsHitTesting(false)
    }
}

// MARK: - HorizonRegion
// The BELOW-horizon region of the current projection, as an exact
// circle / half-plane path. The zenith is the reliable anchor (the nadir
// IS the eye in NorthIN, so it can't be projected) — the ground is
// whichever side the zenith is NOT on. Even-odd fill: when the ground is
// the EXTERIOR of the projected circle (NorthIN — sky inside, murk out),
// the path is a huge rect + the circle and eoFill carves the hole.
private struct HorizonRegion: Shape {

    let camera: SkyCamera

    func path(in rect: CGRect) -> Path {
        let vp = camera.viewpoint

        // Sample the horizon around the circle; keep the projections that
        // exist and are finite (a point can coincide with the slerped eye
        // and blow up — skip it, seven neighbours remain).
        var pts: [CGPoint] = []
        let samples = 8
        for i in 0 ..< samples {
            let t = Double(i) / Double(samples)
            let q = vp.skyPoint(altitude: .zero, at: t)
            if let sc = camera.screen(rotatedEquatorial: q),
               abs(sc.x) < 1e6, abs(sc.y) < 1e6 {
                pts.append(sc)
            }
        }
        guard pts.count >= 3, let sky = skyAnchor() else { return Path() }

        // Three spread samples pin the circle.
        let a = pts[0]
        let b = pts[pts.count / 3]
        let c = pts[(2 * pts.count) / 3]

        // cross = 2·(signed area) — collinearity test scaled by the
        // triangle's extent, so it's zoom-independent.
        let ab    = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ac    = CGPoint(x: c.x - a.x, y: c.y - a.y)
        let cross = ab.x * ac.y - ab.y * ac.x
        let span  = hypot(ab.x, ab.y) * hypot(ac.x, ac.y)
        if abs(cross) < span * 1e-4 { return halfPlane(a, c, sky: sky, in: rect) }

        // Circumcircle through a, b, c.
        let d  = 2 * cross
        let a2 = a.x * a.x + a.y * a.y
        let b2 = b.x * b.x + b.y * b.y
        let c2 = c.x * c.x + c.y * c.y
        let ux = (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d
        let uy = (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d
        let r  = hypot(a.x - ux, a.y - uy)

        // Degenerate-huge circle → indistinguishable from a line on
        // screen; the half-plane path avoids astronomical CGRects.
        guard r < 1e5 else { return halfPlane(a, c, sky: sky, in: rect) }

        let circle = CGRect(x: ux - r, y: uy - r, width: r * 2, height: r * 2)
        var path = Path()
        if hypot(sky.x - ux, sky.y - uy) <= r {
            // Sky fills the circle's interior — the ground is everything
            // OUTSIDE it: huge rect minus the circle.
            path.addRect(rect.insetBy(dx: -8000, dy: -8000))
        }
        path.addEllipse(in: circle)
        return path
    }

    /// A screen point known to be on the SKY side of the horizon — the
    /// projected zenith, with high-altitude fallbacks for the poses where
    /// the zenith itself sits behind the slerped eye.
    private func skyAnchor() -> CGPoint? {
        if let sc = camera.screen(rotatedEquatorial: camera.viewpoint.originVector) {
            return sc
        }
        for t in [0.0, 0.25, 0.5, 0.75] {
            let q = camera.viewpoint.skyPoint(altitude: .degrees(60), at: t)
            if let sc = camera.screen(rotatedEquatorial: q) { return sc }
        }
        return nil
    }

    /// Horizon projects as a (near-)line through `a`–`c`: the region is
    /// the half-plane OPPOSITE the sky side — the ground.
    private func halfPlane(_ a: CGPoint, _ c: CGPoint,
                           sky: CGPoint, in rect: CGRect) -> Path {
        let len = hypot(c.x - a.x, c.y - a.y)
        guard len > 1e-6 else { return Path() }
        let dir  = CGPoint(x: (c.x - a.x) / len, y: (c.y - a.y) / len)
        var n    = CGPoint(x: -dir.y, y: dir.x)
        if (sky.x - a.x) * n.x + (sky.y - a.y) * n.y > 0 {
            n = CGPoint(x: -n.x, y: -n.y)              // flip AWAY from the sky
        }
        let L: CGFloat = 20000
        var path = Path()
        path.move(to:    CGPoint(x: a.x - dir.x * L,        y: a.y - dir.y * L))
        path.addLine(to: CGPoint(x: c.x + dir.x * L,        y: c.y + dir.y * L))
        path.addLine(to: CGPoint(x: c.x + (dir.x + n.x) * L, y: c.y + (dir.y + n.y) * L))
        path.addLine(to: CGPoint(x: a.x + (n.x - dir.x) * L, y: a.y + (n.y - dir.y) * L))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
// Only legible over something — the frost is the region BELOW the horizon.
#Preview("Frosted ground") {
    PreviewSky.night {
        CelestialGridCanvas(camera: PreviewSky.camera)
        HorizonBlurOverlay(camera: PreviewSky.camera)
    }
}
#endif

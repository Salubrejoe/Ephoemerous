import SwiftUI
import simd
import LoreKit

// MARK: - StarsCanvas
// The generic star field — plain filled dots, the layer that MUST stay
// Canvas (thousands of fills is its whole reason to exist). The stress
// test for the architecture: if it pans/zooms smoothly, it's *because*
// the draw closure isn't re-running — `Equatable` on the (frozen) camera
// lets SwiftUI skip the redraw during a gesture, and the shared parent
// transform moves the already-rendered raster for free.
//
// Stars project from their precomputed `equatorialVector` (un-precessed —
// precession is arcminutes, invisible here), sidereally rotated then
// stereographically projected by the camera. Below-horizon stars project
// outside the disc and are culled by the canvas-bounds test.
struct StarsCanvas: View, Equatable {
    let camera: SkyCamera
    let stars:  [EStar]

    // Skip the redraw unless the committed camera changed. `stars` is a
    // fixed catalogue, so its count is a sufficient (cheap) tiebreak — no
    // O(n) array compare per gesture frame.
    static func == (l: Self, r: Self) -> Bool {
        l.camera == r.camera && l.stars.count == r.stars.count
    }

    var body: some View {
        Canvas {
            ctx,
            size in
            for star in stars {
                guard let sc = camera.screen(equatorial: star.equatorialVector) else { continue }
                guard sc.x > -2,
                      sc.x < size.width  + 2,
                      sc.y > -2,
                      sc.y < size.height + 2 else { continue }
                let r = Self.radius(forMagnitude: star.magnitude)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(
                        EArtist.shared.gridColor.opacity(Self.opacity(forMagnitude: star.magnitude))
                    )
                )
            }
        }
    }

    /// Brighter (lower magnitude) → bigger dot.
    private static func radius(forMagnitude m: Double) -> CGFloat {
        CGFloat(max(0.5, (6.0 - m) * 0.34))
    }
    /// Faint stars dim out so the field reads as depth, not noise.
    private static func opacity(forMagnitude m: Double) -> Double {
        min(1, max(0.35, (6.5 - m) / 6.5))
    }
}

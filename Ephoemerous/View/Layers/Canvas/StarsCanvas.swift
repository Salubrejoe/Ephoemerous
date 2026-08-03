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
    /// Favourites are represented by their `.followedStar` badge + heart, so
    /// they're skipped here — otherwise a bright favourite's white field dot,
    /// riding the parent zoom transform, balloons out from behind its
    /// constant-size badge mid-pinch. Checked in the (frozen) draw loop, so
    /// it costs nothing per gesture frame.
    let favouriteIDs: Set<String>
    /// Proper-named, non-favourite stars. Past `namedStarDotIn` these get a
    /// dedicated tier-0 spectral dot (NamedStarDotsCanvas) that crossfades
    /// into their badge (StarLabels) — so the plain field dot underneath
    /// becomes a SECOND mark for one star, poking out from behind the badge.
    /// That was the stray grey dot beside an unfavourited Betelgeuse; it
    /// vanished when the star was favourited only because favourites were
    /// already excluded above. Skipped here past the same tier, so the
    /// handoff is clean either way.
    let namedIDs: Set<String>

    // Skip the redraw unless the committed camera changed. `stars` is a
    // fixed catalogue, so its count is a sufficient (cheap) tiebreak — no
    // O(n) array compare per gesture frame. `favouriteIDs` is a handful, so
    // comparing it keeps the field in sync when a star is (un)favourited.
    static func == (l: Self, r: Self) -> Bool {
        l.camera == r.camera
            && l.stars.count == r.stars.count
            && l.favouriteIDs == r.favouriteIDs
            && l.namedIDs == r.namedIDs
    }

    var body: some View {
        Canvas {
            ctx,
            size in
            // The tier at which a named star's own dot takes over. Read
            // once — not per star — and compared against the COMMITTED
            // camera scale, since this canvas is frozen during a gesture.
            let namedDotIn   = EArtist.shared.namedStarDotIn
            let namedHandsOff = camera.scale >= namedDotIn

            for star in stars {
                guard !favouriteIDs.contains(star.id) else { continue }   // drawn as a badge
                // Named stars hand off to their own dot / badge past the tier.
                if namedHandsOff, namedIDs.contains(star.id) { continue }
                guard let sc = camera.screen(equatorial: star.equatorialVector) else { continue }
                guard sc.x > -2,
                      sc.x < size.width  + 2,
                      sc.y > -2,
                      sc.y < size.height + 2 else { continue }
                let r = Self.radius(forMagnitude: star.magnitude, scale: camera.scale)
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

    // Zoom-growth tunables ▼ TWEAK HERE ▼
    // How much dots grow with the COMMITTED scale. Computed in the frozen
    // Canvas, so it costs nothing per gesture frame (redraws on commit only).
    //   zoomExp 0 = fixed size (old look, harshest commit "pop")
    //           1 = grows with the zoom (no pop, but balloons)
    //         ~0.5 = bigger at high scale with a gentle, near-imperceptible
    //                commit adjustment.
    private static let zoomExp:    CGFloat = 0.5
    private static let zoomAnchor: CGFloat = 90   // default/min scale → factor 1 (default view unchanged)
    private static let zoomCap:    CGFloat = 4    // clamp growth so max-zoom dots don't balloon

    /// Base dot size by magnitude (brighter → bigger), before the zoom factor.
    private static func baseRadius(forMagnitude m: Double) -> CGFloat {
        CGFloat(max(0.5, (6.0 - m) * 0.34))
    }

    /// Dot radius = base × a sub-linear function of the committed `scale`, so
    /// stars grow as you zoom in without ballooning. Frozen-camera input →
    /// the Canvas still redraws only on commit.
    private static func radius(forMagnitude m: Double, scale: CGFloat) -> CGFloat {
        let factor = min(zoomCap, pow(max(scale, zoomAnchor) / zoomAnchor, zoomExp))
        return baseRadius(forMagnitude: m) * factor
    }
    /// Faint stars dim out so the field reads as depth, not noise.
    private static func opacity(forMagnitude m: Double) -> Double {
        min(1, max(0.35, (6.5 - m) / 6.5))
    }
}

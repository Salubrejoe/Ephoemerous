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
    let stars:  [Star]
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
            let namedDotIn   = Artist.shared.namedStarDotIn
            let namedHandsOff = camera.scale >= namedDotIn

            let a      = Artist.shared
            let limit  = Self.limitingMagnitude(scale: camera.scale)
            let zenith = camera.viewpoint.originVector       // earth-fixed, same frame as the horizon
            for star in stars {
                // Brightest first, so the first star past the limit ends
                // the field — everything after it is fainter still.
                guard star.magnitude < limit else { break }
                guard !favouriteIDs.contains(star.id) else { continue }   // drawn as a badge
                // Named stars hand off to their own dot / badge past the tier.
                if namedHandsOff, namedIDs.contains(star.id) { continue }
                guard let sc = camera.screen(equatorial: star.equatorialVector) else { continue }
                guard sc.x > -2,
                      sc.x < size.width  + 2,
                      sc.y > -2,
                      sc.y < size.height + 2 else { continue }
                // The shared field-star style (see `Artist+StarField`);
                // stars at the edge of the limit fade in rather than pop.
                a.drawFieldStar(ctx,
                                at:           sc,
                                magnitude:    star.magnitude,
                                named:        namedIDs.contains(star.id),
                                scale:        camera.scale,
                                reveal:       Self.reveal(magnitude: star.magnitude, limit: limit),
                                aboveHorizon: simd_dot(star.equatorialVector.sidereallyRotated(by: camera.sidereal),
                                                       zenith) > 0)
            }
        }
    }

    // Limiting magnitude ▼ TWEAK HERE ▼
    // Pinch IS the magnitude slider: zoomed out, only the bright skeleton
    // of the sky; each pinch in lets fainter stars through, the way raising
    // binoculars does. Log-linear between the two anchors, so every
    // doubling of zoom reveals the same step of depth.
    private static let limitAtRest:  Double  = 4.5    // at the wide view
    private static let limitAtDepth: Double  = 7.0    // at full zoom
    private static let restScale:    CGFloat = 90
    private static let depthScale:   CGFloat = 1200
    /// Magnitudes over which a star at the limit fades in.
    private static let revealBand:   Double  = 0.5

    /// Faintest magnitude drawn at a committed `scale`.
    private static func limitingMagnitude(scale: CGFloat) -> Double {
        let t = log(Double(max(scale, restScale) / restScale))
              / log(Double(depthScale / restScale))
        return limitAtRest + (limitAtDepth - limitAtRest) * min(1, t)
    }

    /// 0 at the limit → 1 a `revealBand` brighter, smoothstepped.
    private static func reveal(magnitude m: Double, limit: Double) -> Double {
        let x = max(0, min(1, (limit - m) / revealBand))
        return x * x * (3 - 2 * x)
    }
}

#if DEBUG
#Preview("Star field") {
    PreviewSky.night {
        StarsCanvas(camera: PreviewSky.camera,
                    stars: StarDatabase.shared.workableStars,
                    favouriteIDs: [],
                    namedIDs: [])
    }
}
#endif

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

            let glow   = Self.glowAmount(scale: camera.scale)
            let limit  = Self.limitingMagnitude(scale: camera.scale)
            let ink    = Artist.shared.starColor
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
                let r     = Self.radius(forMagnitude: star.magnitude, scale: camera.scale)
                // Spectral colour for the bright stars only, greying out
                // with magnitude — the way a dark sky actually shows them:
                // faint stars reach the eye colourless.
                let color = star.spectralClass.color
                    .mix(with: ink, by: 1 - Self.chroma(forMagnitude: star.magnitude))
                // Stars at the edge of the limit fade in rather than pop.
                let reveal = Self.reveal(magnitude: star.magnitude, limit: limit)
                // The brightest few glow: the cue that they're light sources,
                // not dots. Fades out as you zoom so it never blooms to soup,
                // and only above the horizon — a star under the ground isn't
                // shining on anyone.
                if star.magnitude < Self.glowBelowMagnitude, glow > 0.01,
                   simd_dot(star.equatorialVector.sidereallyRotated(by: camera.sidereal), zenith) > 0 {
                    let g = r * Self.glowReach
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: sc.x - g, y: sc.y - g, width: g * 2, height: g * 2)),
                        with: .radialGradient(Gradient(colors: [color.opacity(Self.glowStrength * glow), .clear]),
                                              center: sc, startRadius: 0, endRadius: g)
                    )
                }
                // The pentagon squircle, same species as the named stars —
                // a cached path, so it's no dearer than a circle.
                ctx.fill(
                    Artist.shared.starPath(at: sc, radius: r),
                    with: .color(color.opacity(Self.opacity(forMagnitude: star.magnitude) * reveal))
                )
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

    // Colour ▼ TWEAK HERE ▼
    /// Full spectral colour at or brighter than this…
    private static let fullColourMagnitude: Double = 2.0
    /// …fading to plain star ink at this.
    private static let greyMagnitude:       Double = 4.0

    /// How much of its spectral colour a star keeps, 1 → 0 with magnitude.
    private static func chroma(forMagnitude m: Double) -> Double {
        let x = max(0, min(1, (greyMagnitude - m) / (greyMagnitude - fullColourMagnitude)))
        return x * x * (3 - 2 * x)
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
    /// The detail hero's curve: steeper than it was, so the bright stars
    /// carry the field and the faint ones recede.
    private static func baseRadius(forMagnitude m: Double) -> CGFloat {
        CGFloat(max(0.5, (6.5 - m) * 0.42))
    }

    // Glow ▼ TWEAK HERE ▼
    /// Stars brighter than this get a halo (~90 of them).
    private static let glowBelowMagnitude: Double  = 2.5
    /// Halo radius as a multiple of the dot's.
    private static let glowReach:          CGFloat = 4
    /// Halo opacity at its centre, at the default zoom.
    private static let glowStrength:       Double  = 0.35

    /// 1 at the default zoom, falling to 0 as the dots finish growing.
    private static func glowAmount(scale: CGFloat) -> Double {
        let factor = min(zoomCap, pow(max(scale, zoomAnchor) / zoomAnchor, zoomExp))
        return Double(max(0, 1 - (factor - 1) / 1.5))
    }

    /// Dot radius = base × a sub-linear function of the committed `scale`, so
    /// stars grow as you zoom in without ballooning. Frozen-camera input →
    /// the Canvas still redraws only on commit.
    private static func radius(forMagnitude m: Double, scale: CGFloat) -> CGFloat {
        let factor = min(zoomCap, pow(max(scale, zoomAnchor) / zoomAnchor, zoomExp))
        let base   = baseRadius(forMagnitude: m)
        // Zooming grows the field, but never past the cap: an unnamed,
        // untappable dot must stay smaller than the named stars' pentagons
        // and badges. A star already bigger than the cap at rest keeps its
        // resting size (those are the bright, named ones, which hand off to
        // their own marks as you zoom anyway).
        return min(base * factor, max(base, fieldDotMaxRadius))
    }

    /// Largest radius zoom may grow a field dot to — under the named-star
    /// pentagon's 2.6. ▼ TWEAK ▼
    private static let fieldDotMaxRadius: CGFloat = 1.7
    /// Faint stars dim out so the field reads as depth, not noise. The
    /// numerator sits above the 6.5 divisor so the bright end saturates
    /// early — a 1st-magnitude star is flat white, and the ramp spends its
    /// range on the faint half where depth actually reads. ▼ TWEAK ▼
    private static let magnitudeSpan: Double = 4.0
    private static let brightLift:    Double = 7.0
    private static let faintFloor:    Double = 0.35

    private static func opacity(forMagnitude m: Double) -> Double {
        min(1, max(faintFloor, (brightLift - m) / magnitudeSpan))
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

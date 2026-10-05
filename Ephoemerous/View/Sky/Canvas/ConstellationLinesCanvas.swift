import SwiftUI
import simd

// MARK: - SkyLabConstellationLinesCanvas
// The constellation stick-figures — hundreds of segments between
// figure-stars. Canvases (cheap stroking is their job), frozen via
// `.equatable()` so they redraw only on a settle / date / origin /
// favourites change, never per gesture frame; the parent transform
// moves the raster.
//
// Drawn the star-atlas way: every segment STOPS SHORT of its stars, the gap
// sized to how that star is drawn right now (field dot, named pentagon or
// badge), so stars read as nodes and lines as the connections between them
// — never skewered, never a blob where three lines meet. Solid hairlines,
// not dots: dotted was one more speck in a field made of specks.
//
// Favourite constellations stroke SOLID in their myth tint and are always
// present. The rest are a quiet grey hairline, and they RIDE IN WITH THE NAME:
// same tier as `ConstellationLabels` (`textIn` ≈ 190), same smoothstep
// reveal, so the sky gains its joins exactly when it gains its names
// instead of showing joined figures nobody can yet read.
//
// The reveal is a plain `.opacity` on the frozen neutral canvas — a
// CoreAnimation property on the rendered layer, so it tracks the live zoom
// continuously WITHOUT re-running the draw closure. That's why the two
// tiers are two canvases: one colour each, one of them animatable from
// outside. (No scale bucketing needed, unlike `NamedStarDotsCanvas`, which
// has to redraw because its crossfade is per-glyph.)
struct ConstellationLinesCanvas: View {

    let camera:         SkyCamera
    let favouriteTints: [Constellation: Color]
    /// Remembered stars wear a badge — their gaps are the badge's.
    var favouriteIDs:   Set<String> = []
    /// 0…1 from `reveal(scale:)` — the neutral figures' share of the
    /// constellation-name tier. Favourites ignore it.
    var reveal: Double = 1

    /// Constellation text tier — the same threshold `ConstellationLabels`
    /// reads, so the two can't drift apart.
    private static let textIn: Double =
        Artist.shared.poiStyle(for: .constellation).textIn

    /// The neutral figures' VOLUME, on top of the tier reveal. The dotted
    /// grey is scaffolding for reading the sky, not content: at full
    /// strength the whole field webs over the moment the tier is crossed.
    /// Multiplied into the reveal, so it costs nothing — same single
    /// `.opacity` on the frozen canvas. ▼ TWEAK ▼
    private static let neutralVolume: Double = 0.40

    /// The figures' share of the name tier, for the caller to pass back in.
    static func reveal(scale: CGFloat) -> Double {
        POILabelView.tierReveal(scale: scale, threshold: textIn)
    }

    var body: some View {
        ZStack {
            NeutralFigures(camera: camera, tinted: Set(favouriteTints.keys), favouriteIDs: favouriteIDs)
                .equatable()
                .opacity(reveal * Self.neutralVolume)

            FavouriteFigures(camera: camera, tints: favouriteTints, favouriteIDs: favouriteIDs)
                .equatable()
        }
    }
}

// MARK: - NeutralFigures
// Every constellation that isn't a favourite, in one dotted grey path.
private struct NeutralFigures: View, Equatable {

    let camera: SkyCamera
    /// Drawn by `FavouriteFigures` instead — skipped here.
    let tinted: Set<Constellation>
    let favouriteIDs: Set<String>

    var body: some View {
        Canvas { ctx, _ in
            var path = Path()
            for (cons, segs) in ConstellationLines.shared.segments {
                if tinted.contains(cons) { continue }
                append(segs, to: &path, camera: camera, favouriteIDs: favouriteIDs)
            }
            ctx.stroke(path,
                       with: .color(.tertiary),
                       style: StrokeStyle(lineWidth: Artist.shared.figureLineWidth, lineCap: .round))
        }
    }
}

// MARK: - FavouriteFigures
// The kept ones — solid, in their myth tint, at every zoom.
private struct FavouriteFigures: View, Equatable {

    let camera: SkyCamera
    let tints:  [Constellation: Color]
    let favouriteIDs: Set<String>

    var body: some View {
        Canvas { ctx, _ in
            for (cons, tint) in tints {
                guard let segs = ConstellationLines.shared.segments[cons] else { continue }
                var path = Path()
                append(segs, to: &path, camera: camera, favouriteIDs: favouriteIDs)
                ctx.stroke(path, with: .color(tint),
                           style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            }
        }
    }
}

/// Project a figure's segments and append the on-screen lines, each one
/// trimmed back from both stars by that star's gap. A segment is dropped
/// when either endpoint projects behind the viewer, when its two screen
/// points are improbably far apart (the projection seam), or when the gaps
/// would leave nothing of it.
private func append(_ segs: [ConstellationLines.Segment],
                    to path: inout Path,
                    camera: SkyCamera,
                    favouriteIDs: Set<String>) {
    for seg in segs {
        guard let a = camera.screen(equatorial: seg.a.equatorialVector),
              let b = camera.screen(equatorial: seg.b.equatorialVector) else { continue }
        let dx = b.x - a.x, dy = b.y - a.y
        let d2 = dx * dx + dy * dy
        guard d2 < 80_000 else { continue }                  // back-side seam
        guard let (p, q) = Artist.shared.figureSegment(
                from: a, to: b,
                gapA: figureGap(seg.a, scale: camera.scale, favouriteIDs: favouriteIDs),
                gapB: figureGap(seg.b, scale: camera.scale, favouriteIDs: favouriteIDs))
        else { continue }
        path.move(to: p)
        path.addLine(to: q)
    }
}

/// The clear space a line leaves round a star: the radius it's drawn at
/// right now — field dot, named star's pentagon, or the full badge once
/// its tier is reached (a remembered star's, or a named one's) — plus a
/// breath of sky.
private func figureGap(_ star: Star, scale: CGFloat, favouriteIDs: Set<String>) -> CGFloat {
    let a = Artist.shared
    let drawn: CGFloat
    if favouriteIDs.contains(star.id) {
        let style = a.poiStyle(for: .followedStar(star))
        drawn = scale >= style.badgeIn ? style.badgeSize / 2 + a.poiTextBorderWidth : style.dotRadius
    } else if star.properName != nil {
        let style = a.poiStyle(for: .namedStar(star))
        drawn = scale >= style.badgeIn      ? style.badgeSize / 2 + a.poiTextBorderWidth
              : scale >= a.namedStarDotIn   ? style.dotRadius
              : a.fieldStarRadius(magnitude: star.magnitude, scale: scale)
    } else {
        drawn = a.fieldStarRadius(magnitude: star.magnitude, scale: scale)
    }
    return drawn + a.figureGapMargin
}

#if DEBUG
#Preview("Figures") {
    PreviewSky.night {
        ConstellationLinesCanvas(camera: PreviewSky.camera,
                                 favouriteTints: [.Ori: .tertiary],
                                 reveal: 1)
    }
}
#endif

import SwiftUI
import simd

// MARK: - SkyLabConstellationLinesCanvas
// The constellation stick-figures — hundreds of segments between
// figure-stars. Canvases (cheap stroking is their job), frozen via
// `.equatable()` so they redraw only on a settle / date / origin /
// favourites change, never per gesture frame; the parent transform
// moves the raster.
//
// Favourite constellations stroke SOLID in their myth tint and are always
// present. The rest are quiet dotted grey, and they RIDE IN WITH THE NAME:
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
    /// 0…1 from `reveal(scale:)` — the neutral figures' share of the
    /// constellation-name tier. Favourites ignore it.
    var reveal: Double = 1

    /// Constellation text tier — the same threshold `ConstellationLabels`
    /// reads, so the two can't drift apart.
    private static let textIn: Double =
        Artist.shared.poiStyle(for: .constellation).textIn

    /// The figures' share of the name tier, for the caller to pass back in.
    static func reveal(scale: CGFloat) -> Double {
        POILabelView.tierReveal(scale: scale, threshold: textIn)
    }

    var body: some View {
        ZStack {
            NeutralFigures(camera: camera, tinted: Set(favouriteTints.keys))
                .equatable()
                .opacity(reveal)

            FavouriteFigures(camera: camera, tints: favouriteTints)
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

    var body: some View {
        Canvas { ctx, _ in
            var path = Path()
            for (cons, segs) in ConstellationLines.shared.segments {
                if tinted.contains(cons) { continue }
                append(segs, to: &path, camera: camera)
            }
            ctx.stroke(path,
                       with: .color(.tertiary),
                       style: StrokeStyle(lineWidth: 0.7, lineCap: .round, dash: [1.5, 3]))
        }
    }
}

// MARK: - FavouriteFigures
// The kept ones — solid, in their myth tint, at every zoom.
private struct FavouriteFigures: View, Equatable {

    let camera: SkyCamera
    let tints:  [Constellation: Color]

    var body: some View {
        Canvas { ctx, _ in
            for (cons, tint) in tints {
                guard let segs = ConstellationLines.shared.segments[cons] else { continue }
                var path = Path()
                append(segs, to: &path, camera: camera)
                ctx.stroke(path, with: .color(tint),
                           style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            }
        }
    }
}

/// Project a figure's segments and append the on-screen lines. A segment is
/// dropped when either endpoint projects behind the viewer, or when its two
/// screen points are improbably far apart (the projection seam).
private func append(_ segs: [ConstellationLines.Segment],
                    to path: inout Path,
                    camera: SkyCamera) {
    for seg in segs {
        guard let a = camera.screen(equatorial: seg.a.equatorialVector),
              let b = camera.screen(equatorial: seg.b.equatorialVector) else { continue }
        let dx = b.x - a.x, dy = b.y - a.y
        guard dx * dx + dy * dy < 80_000 else { continue }   // back-side seam
        path.move(to: a)
        path.addLine(to: b)
    }
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

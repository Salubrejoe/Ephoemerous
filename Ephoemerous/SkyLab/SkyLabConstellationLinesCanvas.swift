import SwiftUI
import simd

// MARK: - SkyLabConstellationLinesCanvas
// The constellation stick-figures — hundreds of segments between
// figure-stars. A Canvas (cheap stroking is its job), frozen via
// `.equatable()` so it redraws only on a settle / date / origin /
// favourites change, never per gesture frame; the parent transform
// moves the raster.
//
// Favourite constellations stroke SOLID in their myth tint (like
// production); the rest are quiet dotted grey. A segment is dropped when
// either endpoint projects behind the viewer, or when its two screen
// points are improbably far apart (the projection seam).
struct SkyLabConstellationLinesCanvas: View, Equatable {

    let camera:         SkyLabCamera
    let favouriteTints: [EConstellation: Color]

    static func == (l: Self, r: Self) -> Bool {
        l.camera == r.camera && l.favouriteTints == r.favouriteTints
    }

    var body: some View {
        Canvas { ctx, _ in
            var neutral = Path()
            for (cons, segs) in ConstellationLines.shared.segments {
                if favouriteTints[cons] != nil { continue }   // tinted below
                append(segs, to: &neutral)
            }
            ctx.stroke(neutral,
                       with: .color(.secondary.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 0.7, lineCap: .round, dash: [1.5, 3]))

            // Favourites — solid, in their tint.
            for (cons, tint) in favouriteTints {
                guard let segs = ConstellationLines.shared.segments[cons] else { continue }
                var p = Path()
                append(segs, to: &p)
                ctx.stroke(p, with: .color(tint),
                           style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            }
        }
    }

    private func append(_ segs: [ConstellationLines.Segment], to path: inout Path) {
        for seg in segs {
            guard let a = camera.screen(equatorial: seg.a.equatorialVector),
                  let b = camera.screen(equatorial: seg.b.equatorialVector) else { continue }
            let dx = b.x - a.x, dy = b.y - a.y
            guard dx * dx + dy * dy < 80_000 else { continue }   // back-side seam
            path.move(to: a)
            path.addLine(to: b)
        }
    }
}

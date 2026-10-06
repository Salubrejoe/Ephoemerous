import SwiftUI

// MARK: - SpacecraftGlyph
// Each spacecraft's badge is its own silhouette instead of an orb — but a
// BADGE, not a replica: three or four bold shapes, no linework, so it reads
// at 16 pt on a sky full of stars. The ISS is its truss, copper wings and a
// module; Hubble a steel tube across its blue panels; Webb the gold hexagon
// over the lilac sunshield; Tiangong a steel "T" with two violet panels.
//
// Drawn as a set of parts — every part's casing goes down first, then every
// fill — so overlapping parts read as ONE cased silhouette, with the thick
// dark outline only ever on the outside. Each part is lit from above.
//
// Geometry lives in design units where the badge is 14 wide (see
// `SpacecraftShapes`); the canvas leaves room around it for the casing, so
// the border is never clipped by the frame.
//
// A Canvas rasterises at its LAYOUT size, so it must never be enlarged with
// `.scaleEffect` — callers that want it bigger lay it out bigger (see
// `POILabelView.sizeScale`), and then it renders crisp at full resolution.
struct SpacecraftGlyph: View {

    let craft:      Spacecraft
    let casing:     Color
    /// Casing weight, already scale-compensated by the caller.
    let lineWidth:  CGFloat
    /// Masked widget host: only alpha survives, so paint in white shades.
    let masked:     Bool

    /// How thick the casing is, as a multiple of the badge's own border —
    /// ▼ TWEAK the craft's outline here ▼. Half of it shows outside the paint.
    private static let casingWeight: CGFloat = 1.8

    var body: some View {
        Canvas { ctx, size in
            // Room for the casing's outer half on both sides.
            let pad   = lineWidth * Self.casingWeight
            let k     = size.width / (SpacecraftShapes.designWidth + pad)
            let place = CGAffineTransform(translationX: size.width / 2, y: size.height / 2).scaledBy(x: k, y: k)
            let parts = SpacecraftShapes.parts(of: craft).map { ($0.paint, $0.path.applying(place)) }
            // Casing under everything: the fills then cover its inner half.
            for (_, path) in parts {
                ctx.stroke(path, with: .color(casing),
                           style: StrokeStyle(lineWidth: pad, lineJoin: .round))
            }
            for (paint, path) in parts {
                ctx.fill(path, with: shading(paint, in: path.boundingRect))
            }
        }
    }

    /// Each part shades bottom (deep) → top (bright) across its own bounds.
    private func shading(_ paint: SpacecraftShapes.Paint, in rect: CGRect) -> GraphicsContext.Shading {
        let pair = masked ? (Color.white.opacity(0.4), Color.white.opacity(0.8))
                          : Artist.shared.spacecraftPaint(paint)
        return .linearGradient(Gradient(colors: [pair.0, pair.1]),
                               startPoint: CGPoint(x: rect.midX, y: rect.maxY),
                               endPoint:   CGPoint(x: rect.midX, y: rect.minY))
    }
}

// MARK: - SpacecraftShapes
enum SpacecraftShapes {

    static let designWidth: CGFloat = 14

    enum Paint { case steel, copper, blue, violet, gold, shield }

    struct Part { let path: Path; let paint: Paint }

    static func parts(of craft: Spacecraft) -> [Part] {
        switch craft {
        case .iss:      return iss
        case .hubble:   return hubble
        case .jwst:     return webb
        case .tiangong: return tiangong
        }
    }

    // MARK: ISS — the truss, a copper wing each side, the module at the heart
    private static var iss: [Part] {
        [Part(path: box(x: -7,   y: -0.6, w: 14,  h: 1.2, r: 0.3), paint: .steel),
         Part(path: box(x: -7,   y: -3.9, w: 3.7, h: 7.8, r: 0.6), paint: .copper),
         Part(path: box(x:  3.3, y: -3.9, w: 3.7, h: 7.8, r: 0.6), paint: .copper),
         Part(path: box(x: -1.5, y: -1.7, w: 3,   h: 3.4, r: 1.0), paint: .steel)]
    }

    // MARK: Hubble — a steel tube across its blue panels, tilted
    private static let hubbleTilt = CGAffineTransform(rotationAngle: -32 * .pi / 180)

    private static var hubble: [Part] {
        [Part(path: box(x: -0.4, y: -6.3, w: 2.2, h: 12.6, r: 0.5), paint: .blue),
         Part(path: box(x: -4.9, y: -1.9, w: 9.8, h: 3.8,  r: 1.3), paint: .steel)]
        .map { Part(path: $0.path.applying(hubbleTilt), paint: $0.paint) }
    }

    // MARK: Webb — the gold hexagonal mirror over the lilac sunshield
    private static var webb: [Part] {
        [Part(path: polygon([(-7, 2.6), (-2.6, 0.2), (2.6, 0.2), (7, 2.6), (2.6, 5.8), (-2.6, 5.8)]), paint: .shield),
         Part(path: hexagon(centre: CGPoint(x: 0, y: -2.0), radius: 3.9), paint: .gold)]
    }

    // MARK: Tiangong — a steel "T", a violet wing under each arm
    private static var tiangong: [Part] {
        [Part(path: box(x: -6.7, y:  0.2, w: 4.7,  h: 5.6,  r: 0.6), paint: .violet),
         Part(path: box(x:  2.0, y:  0.2, w: 4.7,  h: 5.6,  r: 0.6), paint: .violet),
         Part(path: box(x: -1.25, y: -4.2, w: 2.5, h: 10.6, r: 0.9), paint: .steel),
         Part(path: box(x: -6.7, y: -6.2, w: 13.4, h: 2.5,  r: 0.9), paint: .steel)]
    }

    // MARK: Helpers
    private static func box(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    private static func polygon(_ pts: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        p.addLines(pts.map { CGPoint(x: $0.0, y: $0.1) })
        p.closeSubpath()
        return p
    }

    /// Pointy-topped hexagon.
    private static func hexagon(centre c: CGPoint, radius r: CGFloat) -> Path {
        polygon((0..<6).map { i in
            let a = CGFloat.pi / 3 * CGFloat(i) + .pi / 6
            return (c.x + r * cos(a), c.y + r * sin(a))
        })
    }
}

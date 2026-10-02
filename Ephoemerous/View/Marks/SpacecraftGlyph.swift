import SwiftUI

// MARK: - SpacecraftGlyph
// Each spacecraft's badge is its own silhouette instead of an orb: the ISS's
// truss and copper wings, Hubble's tube and blue panels, Webb's gold mirror
// over its sunshield, Tiangong's "T". Drawn as a set of parts — every part's
// casing goes down first, then every fill — so overlapping parts read as ONE
// cased silhouette, the dark outline only ever on the outside.
//
// Geometry lives in design units where the badge is 14 wide (see
// `SpacecraftShapes`); the Canvas scales it to the frame. The promoted pin
// adds fine linework (panel seams, Webb's 18 segments and struts).
struct SpacecraftGlyph: View {

    let craft:      Spacecraft
    let casing:     Color
    /// Casing weight, already scale-compensated by the caller.
    let lineWidth:  CGFloat
    let fullDetail: Bool
    /// Masked widget host: only alpha survives, so paint in white shades.
    let masked:     Bool

    var body: some View {
        Canvas { ctx, size in
            let k     = size.width / SpacecraftShapes.designWidth
            let place = CGAffineTransform(translationX: size.width / 2, y: size.height / 2).scaledBy(x: k, y: k)
            let parts = SpacecraftShapes.parts(of: craft).map { ($0.paint, $0.path.applying(place)) }
            // Casing under everything: the fills then cover its inner half.
            for (_, path) in parts {
                ctx.stroke(path, with: .color(casing),
                           style: StrokeStyle(lineWidth: lineWidth * 1.18, lineJoin: .round))
            }
            for (paint, path) in parts {
                ctx.fill(path, with: shading(paint, in: path.boundingRect))
            }
            guard fullDetail, !masked else { return }
            for line in SpacecraftShapes.detail(of: craft) {
                ctx.stroke(line.path.applying(place), with: .color(line.color),
                           lineWidth: lineWidth * line.weight)
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

    enum Paint { case steel, copper, blue, violet, gold, shield, aperture }

    struct Part { let path: Path; let paint: Paint }
    /// Fine linework; `weight` is a fraction of the casing width.
    struct Line { let path: Path; let color: Color; let weight: CGFloat }

    static func parts(of craft: Spacecraft) -> [Part] {
        switch craft {
        case .iss:      return iss
        case .hubble:   return hubble
        case .jwst:     return webb
        case .tiangong: return tiangong
        }
    }

    static func detail(of craft: Spacecraft) -> [Line] {
        switch craft {
        case .iss:      return issDetail
        case .hubble:   return hubbleDetail
        case .jwst:     return webbDetail
        case .tiangong: return tiangongDetail
        }
    }

    // MARK: ISS — truss, four copper wing columns, modules at the heart
    private static let issWings: [CGFloat] = [-5.7, -3.5, 2.1, 4.3]

    private static var iss: [Part] {
        issWings.map { Part(path: box(x: $0, y: -3.6, w: 1.4, h: 7.2, r: 0.15), paint: .copper) }
        + [Part(path: box(x: -7,   y: -0.45, w: 14,  h: 0.9, r: 0.2), paint: .steel),
           Part(path: box(x: -1.3, y: -1.0,  w: 2.6, h: 2.7, r: 0.5), paint: .steel)]
    }

    private static var issDetail: [Line] {
        issWings.flatMap { x in
            [Line(path: segment(x, 0, x + 1.4, 0), color: .black.opacity(0.55), weight: 0.19)]
            + [-2.4, -1.2, 1.2, 2.4].map {
                Line(path: segment(x, $0, x + 1.4, $0), color: .black.opacity(0.28), weight: 0.13)
            }
        }
        + [Line(path: segment(-1.3, 0.45, 1.3, 0.45), color: .black.opacity(0.55), weight: 0.19)]
    }

    // MARK: Hubble — steel tube, open aperture, two blue panels, tilted
    private static let hubbleTilt = CGAffineTransform(rotationAngle: -32 * .pi / 180)

    private static var hubble: [Part] {
        [Part(path: box(x: -0.1, y: -6.0, w: 2.1, h: 4.4, r: 0.15), paint: .blue),
         Part(path: box(x: -0.1, y:  1.6, w: 2.1, h: 4.4, r: 0.15), paint: .blue),
         Part(path: box(x: -4.6, y: -1.7, w: 9.2, h: 3.4, r: 1.0),  paint: .steel),
         Part(path: Path(ellipseIn: CGRect(x: 3.85, y: -1.7, width: 1.5, height: 3.4)), paint: .aperture)]
        .map { Part(path: $0.path.applying(hubbleTilt), paint: $0.paint) }
    }

    private static var hubbleDetail: [Line] {
        [Line(path: segment(-1.2, -1.7, -1.2, 1.7), color: .black.opacity(0.55), weight: 0.19),
         Line(path: segment(0.95, -6.0, 0.95, -1.6), color: .black.opacity(0.35), weight: 0.15),
         Line(path: segment(0.95,  1.6, 0.95,  6.0), color: .black.opacity(0.35), weight: 0.15),
         Line(path: Path(ellipseIn: CGRect(x: 3.85, y: -1.7, width: 1.5, height: 3.4)),
              color: Color(red: 0.78, green: 0.82, blue: 0.86), weight: 0.23)]
        .map { Line(path: $0.path.applying(hubbleTilt), color: $0.color, weight: $0.weight) }
    }

    // MARK: Webb — gold hexagonal mirror over the kite sunshield
    private static let mirrorCentre = CGPoint(x: 0, y: -2.2)

    private static var webb: [Part] {
        [Part(path: polygon([(-7, 2.3), (-2.4, 0.4), (2.4, 0.4), (7, 2.3), (2.4, 5.4), (-2.4, 5.4)]), paint: .shield),
         Part(path: hexagon(centre: mirrorCentre, radius: 3.6), paint: .gold)]
    }

    private static var webbDetail: [Line] {
        // The 18 segments: two rings of hexes around the missing centre.
        let r = 0.68, w = sqrt(3) * r
        var lines: [Line] = []
        for q in -2...2 { for s in -2...2 {
            let t = -q - s
            guard max(abs(q), abs(s), abs(t)) <= 2, (q, s) != (0, 0) else { continue }
            let c = CGPoint(x: mirrorCentre.x + w * (Double(q) + Double(s) / 2),
                            y: mirrorCentre.y + 1.5 * r * Double(s))
            lines.append(Line(path: hexagon(centre: c, radius: r * 0.93),
                              color: Color(red: 0.47, green: 0.31, blue: 0.04).opacity(0.65), weight: 0.19))
        }}
        // Secondary mirror on its three struts, and the sunshield's fold.
        let strut = Color(red: 0.16, green: 0.16, blue: 0.2).opacity(0.8)
        lines += [Line(path: segment(-3.1, -0.4, 0, -4.6), color: strut, weight: 0.19),
                  Line(path: segment( 3.1, -0.4, 0, -4.6), color: strut, weight: 0.19),
                  Line(path: segment( 0,   -5.8, 0, -4.6), color: strut, weight: 0.19),
                  Line(path: Path(ellipseIn: CGRect(x: -0.32, y: -4.92, width: 0.64, height: 0.64)), color: strut, weight: 0.6),
                  Line(path: segment(-4.6, 2.9, 4.6, 2.9),
                       color: Color(red: 0.35, green: 0.31, blue: 0.47).opacity(0.45), weight: 0.19)]
        return lines
    }

    // MARK: Tiangong — labs as the crossbar, core as the stem, wings at the ends
    private static var tiangong: [Part] {
        [Part(path: box(x: -5.6, y: -6.4, w: 8.2, h: 1.3, r: 0.12),  paint: .violet),   // Wentian's wings
         Part(path: box(x: -5.6, y:  5.1, w: 8.2, h: 1.3, r: 0.12),  paint: .violet),   // Mengtian's wings
         Part(path: box(x:  4.2, y: -3.2, w: 1.1, h: 6.4, r: 0.12),  paint: .violet),   // Tianhe's wings
         Part(path: box(x: -2.2, y: -5.4, w: 1.9, h: 10.8, r: 0.8),  paint: .steel),    // the two labs
         Part(path: box(x: -0.6, y: -1.0, w: 6.4, h: 2.0,  r: 0.8),  paint: .steel)]    // Tianhe core
    }

    private static var tiangongDetail: [Line] {
        [Line(path: segment(-5.6, -5.75, 2.6, -5.75), color: .black.opacity(0.55), weight: 0.15),
         Line(path: segment(-5.6,  5.75, 2.6,  5.75), color: .black.opacity(0.55), weight: 0.15),
         Line(path: segment( 4.75, -3.2, 4.75,  3.2), color: .black.opacity(0.55), weight: 0.15),
         Line(path: segment(-2.2,  0,   -0.3,   0),   color: .black.opacity(0.55), weight: 0.19)]
    }

    // MARK: Helpers
    private static func box(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    private static func segment(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
        var p = Path(); p.move(to: CGPoint(x: x1, y: y1)); p.addLine(to: CGPoint(x: x2, y: y2)); return p
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

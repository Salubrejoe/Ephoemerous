import SwiftUI

// MARK: - Galaxy glyphs
// Each Local Group galaxy's silhouette, drawn with the shared kit in
// `DeepSkyGlyph` (see `Artist+Galaxies` for the cast):
//   • Andromeda  — a golden bulge through a long tilted disc. Saturn's
//                  grammar: the disc's far half behind the bulge, its near
//                  half in front with a cased edge, a dust lane across it.
//   • Triangulum — a disc seen half face-on, two bright arms wound across
//                  it out of a small core
//   • M32 / M110 — ellipticals: a compact oval, a tall soft one
//   • LMC / SMC  — clouds: a lumpy body round a bright bar; a slanted bean
//                  with its Wing

// MARK: - GalaxyShapes
enum GalaxyShapes {

    enum Paint { case disc, warm, bulge, armDisc, arm, core, elliptical, dwarf, cloud, smallCloud, bar, nebula }

    /// The widest the silhouette reaches, in design units — fitted to the
    /// badge's frame.
    static func designSize(of galaxy: LocalGalaxy) -> CGFloat {
        switch galaxy {
        case .andromeda, .triangulum, .lmc: return 16
        case .smc:                          return 13
        case .m110:                         return 11
        case .m32:                          return 9
        }
    }

    // MARK: Andromeda  ▼ TWEAK ▼
    static let andromedaTilt:  Angle   = .degrees(-16)
    /// The disc's half-length and half-thickness — about 3.5 : 1, the way
    /// it sits on the sky.
    static let andromedaDisc:  CGSize  = CGSize(width: 8,   height: 2.3)
    /// The bulge, a touch flattened along the disc.
    static let andromedaBulge: CGSize  = CGSize(width: 2.7, height: 2.2)

    // MARK: Triangulum  ▼ TWEAK ▼
    static let triangulumTilt:   Angle   = .degrees(-24)
    /// How much the disc is foreshortened — it's seen about 55° from face-on.
    static let triangulumSquash: CGFloat = 0.70
}

// MARK: - Drawing
extension GlyphPainter {

    mutating func draw(_ galaxy: LocalGalaxy, fullDetail: Bool) {
        switch galaxy {
        case .andromeda:  drawAndromeda(fullDetail: fullDetail)
        case .triangulum: drawTriangulum(fullDetail: fullDetail)
        case .m32:        drawM32()
        case .m110:       drawM110(fullDetail: fullDetail)
        case .lmc:        drawLMC(fullDetail: fullDetail)
        case .smc:        drawSMC(fullDetail: fullDetail)
        }
    }

    // MARK: Andromeda

    private mutating func drawAndromeda(fullDetail: Bool) {
        let tilt  = GalaxyShapes.andromedaTilt
        let a     = GalaxyShapes.andromedaDisc.width,  b  = GalaxyShapes.andromedaDisc.height
        let bx    = GalaxyShapes.andromedaBulge.width, by = GalaxyShapes.andromedaBulge.height
        let disc  = ellipse(width: a * 2,  height: b * 2,  tilt: tilt)
        let bulge = ellipse(width: bx * 2, height: by * 2, tilt: tilt)

        caseOutline([disc, bulge])
        // The far half of the disc, the bulge rising through it…
        andromedaDisc(disc, fullDetail: fullDetail)
        fill(bulge, paint(.bulge))
        glow(width: bx * 1.2, height: by * 1.1, tilt: tilt, colour: paint(.core).1, peak: 1)
        // …and the near half crossing in front. Its edge over the bulge is
        // where the bulge meets the disc's plane: the bulge's own girth,
        // foreshortened as much as the disc is.
        let girth = bx * b / a
        clipped(to: andromedaNearHalf(a: a, b: b, bulge: bx, girth: girth, tilt: tilt)) {
            $0.andromedaDisc(disc, fullDetail: fullDetail)
        }
        stroke(arc(width: bx * 2, height: girth * 2, from: .pi, to: 0, tilt: tilt),
               colour: casing, points: casingWidth * 0.35)
    }

    /// The disc with what's ON it: golden towards the middle, a dust lane
    /// along its near side.
    private mutating func andromedaDisc(_ disc: Path, fullDetail: Bool) {
        let tilt = GalaxyShapes.andromedaTilt
        fill(disc, paint(.disc))
        glow(width: 9.6, height: 2.9, tilt: tilt, colour: paint(.warm).1, peak: 0.9)
        guard !masked else { return }
        stroke(arc(width: 11.4, height: 2.6, from: 0.10 * .pi, to: 0.90 * .pi, tilt: tilt),
               colour: Artist.shared.galaxyDust.opacity(0.75), width: 0.5)
        if fullDetail {
            stroke(arc(width: 13.8, height: 3.5, from: 0.18 * .pi, to: 0.82 * .pi, tilt: tilt),
                   colour: Artist.shared.galaxyDust.opacity(0.5), width: 0.32)
        }
    }

    /// The near half of the disc: below its long axis, except where the
    /// bulge stands above the disc's plane.
    private func andromedaNearHalf(a: CGFloat, b: CGFloat, bulge bx: CGFloat, girth: CGFloat, tilt: Angle) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -a, y: 0))
        p.addLine(to: CGPoint(x: -bx, y: 0))
        for i in 0...24 {
            let t = CGFloat.pi * (1 - CGFloat(i) / 24)
            p.addLine(to: CGPoint(x: bx * cos(t), y: girth * sin(t)))
        }
        p.addLine(to: CGPoint(x: a, y: 0))
        for i in 0...36 {
            let t = CGFloat.pi * CGFloat(i) / 36
            p.addLine(to: CGPoint(x: a * cos(t), y: b * sin(t)))
        }
        p.closeSubpath()
        return p.applying(CGAffineTransform(rotationAngle: tilt.radians))
    }

    // MARK: Triangulum

    private mutating func drawTriangulum(fullDetail: Bool) {
        // The disc, then its two arms in light across it, out to the rim.
        let disc = triangulumPlane(Path(ellipseIn: CGRect(x: -7.8, y: -7.8, width: 15.6, height: 15.6)))
        caseOutline([disc])
        fill(disc, paint(.armDisc))
        clipped(to: disc) { inner in
            for arm in 0..<2 { inner.fill(inner.triangulumArm(arm), inner.paint(.arm), over: disc.boundingRect) }
        }
        let core = triangulumPlane(Path(ellipseIn: CGRect(x: -1.9, y: -1.9, width: 3.8, height: 3.8)))
        glow(width: 6.0, height: 6.0 * GalaxyShapes.triangulumSquash,
             tilt: GalaxyShapes.triangulumTilt, colour: paint(.core).1, peak: 0.8)
        fill(core, paint(.core))
        if fullDetail {
            // NGC 604 and a smaller sister, pink on the arms.
            knot(at: triangulumPlane(spiralCentre(arm: 0, t: 0.70)), radius: 0.75)
            knot(at: triangulumPlane(spiralCentre(arm: 1, t: 0.55)), radius: 0.5)
        }
    }

    /// One arm: a band along a logarithmic spiral, thick at the core and
    /// tapering to its tip, laid in the tilted plane.
    private func triangulumArm(_ arm: Int) -> Path {
        let samples = 32
        var left = [CGPoint](), right = [CGPoint]()
        for i in 0...samples {
            let t      = CGFloat(i) / CGFloat(samples)
            let p      = spiralCentre(arm: arm, t: t)
            let ahead  = spiralCentre(arm: arm, t: min(1, t + 0.01))
            let behind = spiralCentre(arm: arm, t: max(0, t - 0.01))
            let dx = ahead.x - behind.x, dy = ahead.y - behind.y
            let len   = max(0.0001, sqrt(dx * dx + dy * dy))
            let half  = (3.4 * (1 - t) + 1.4 * t) / 2
            let n     = CGPoint(x: -dy / len * half, y: dx / len * half)
            left.append(CGPoint(x: p.x + n.x, y: p.y + n.y))
            right.append(CGPoint(x: p.x - n.x, y: p.y - n.y))
        }
        var path = Path()
        path.addLines(left + right.reversed())
        path.closeSubpath()
        return triangulumPlane(path)
    }

    /// A point `t` (0 core … 1 tip) along an arm's centreline, face-on.
    private func spiralCentre(arm: Int, t: CGFloat) -> CGPoint {
        let turn: CGFloat = 1.15 * .pi
        let inner: CGFloat = 1.2, outer: CGFloat = 7.6
        let theta = t * turn
        let rho   = inner * exp(log(outer / inner) / turn * theta)
        let angle = theta + CGFloat(arm) * .pi + 0.4
        return CGPoint(x: rho * cos(angle), y: rho * sin(angle))
    }

    /// Face-on → as seen: foreshortened, then tilted.
    private func triangulumPlane(_ path: Path) -> Path {
        path.applying(CGAffineTransform(scaleX: 1, y: GalaxyShapes.triangulumSquash)
            .concatenating(CGAffineTransform(rotationAngle: GalaxyShapes.triangulumTilt.radians)))
    }

    private func triangulumPlane(_ p: CGPoint) -> CGPoint {
        p.applying(CGAffineTransform(scaleX: 1, y: GalaxyShapes.triangulumSquash)
            .concatenating(CGAffineTransform(rotationAngle: GalaxyShapes.triangulumTilt.radians)))
    }

    // MARK: M32 and M110

    /// An elliptical is drawn the way astronomers map one: nested
    /// isophotes, each step brighter, to a bright core.
    private mutating func drawM32() {
        let tilt = Angle.degrees(-20)
        let body = ellipse(width: 9, height: 7.4, tilt: tilt)
        caseOutline([body])
        fill(body, paint(.elliptical))
        isophote(width: 6.2, height: 5.0, tilt: tilt, colour: paint(.elliptical).1, step: 0.5)
        isophote(width: 3.6, height: 2.9, tilt: tilt, colour: paint(.core).1, step: 0.85)
        glow(width: 2.2, height: 1.9, tilt: .zero, colour: .white, peak: 1)
    }

    /// Taller and looser than M32, and its isophotes TWIST — each turned a
    /// little from the one outside it, as M110's really are.
    private mutating func drawM110(fullDetail: Bool) {
        let body = ellipse(width: 6.4, height: 11, tilt: .degrees(14))
        caseOutline([body])
        fill(body, paint(.dwarf))
        isophote(width: 4.4, height: 7.4, tilt: .degrees(4),  colour: paint(.dwarf).1, step: 0.55)
        isophote(width: 2.4, height: 3.8, tilt: .degrees(-8), colour: paint(.core).1, step: 0.7)
        if fullDetail, !masked {
            // Its dust patches — unusual in a dwarf elliptical.
            glow(at: CGPoint(x: 0.4, y: -1.0), width: 0.9, height: 0.7, tilt: .zero,
                 colour: Artist.shared.galaxyDust, peak: 0.6)
            glow(at: CGPoint(x: -0.6, y: 0.8), width: 0.7, height: 0.6, tilt: .zero,
                 colour: Artist.shared.galaxyDust, peak: 0.5)
        }
    }

    // MARK: The Clouds

    private mutating func drawLMC(fullDetail: Bool) {
        let parts = [ellipse(at: CGPoint(x:  0.5, y:  0.6), width: 13,  height: 10.6, tilt: .degrees(-10)),
                     ellipse(at: CGPoint(x: -0.8, y: -4.3), width: 9.5, height: 4.6,  tilt: .degrees(-12)),
                     ellipse(at: CGPoint(x: -5.4, y:  1.6), width: 4.6, height: 4.2,  tilt: .zero)]
        caseOutline(parts)
        let bounds = parts.dropFirst().reduce(parts[0].boundingRect) { $0.union($1.boundingRect) }
        for part in parts { fill(part, paint(.cloud), over: bounds) }
        // The bar, off-centre, nearly east–west.
        let barTilt = Angle.degrees(-16)
        glow(at: CGPoint(x: 0.4, y: 1.3), width: 12.6, height: 5.4, tilt: barTilt,
             colour: paint(.bar).1, peak: 0.5)
        let bar = capsule(at: CGPoint(x: 0.4, y: 1.3), length: 9.6, thickness: 2.8, tilt: barTilt)
        blurred(radius: 0.6) { $0.fill(bar, paint(.bar)) }
        // The Tarantula, north-east of the bar's eastern end.
        knot(at: CGPoint(x: -3.9, y: -1.7), radius: 1.3)
        if fullDetail {
            knot(at: CGPoint(x: 2.6, y: -3.6), radius: 0.5)
            knot(at: CGPoint(x: -1.9, y: -4.7), radius: 0.45)
        }
    }

    private mutating func drawSMC(fullDetail: Bool) {
        let beanTilt = Angle.degrees(38)
        let parts = [ellipse(at: CGPoint(x:  1.2, y: -1.0), width: 11.6, height: 5.6, tilt: beanTilt),
                     ellipse(at: CGPoint(x: -0.6, y:  1.6), width: 5.8,  height: 4.2, tilt: .degrees(-14))]
        caseOutline(parts)
        let bounds = parts[0].boundingRect.union(parts[1].boundingRect)
        for part in parts { fill(part, paint(.smallCloud), over: bounds) }
        // The bar, along the bean.
        glow(at: CGPoint(x: 1.0, y: -0.9), width: 8.2, height: 3.2, tilt: beanTilt,
             colour: paint(.bar).1, peak: 0.9)
        if fullDetail {
            // NGC 346, at the bar's north-eastern end.
            knot(at: CGPoint(x: -1.7, y: -3.2), radius: 0.7)
        }
    }

    // MARK: Paint

    private func paint(_ p: GalaxyShapes.Paint) -> (Color, Color) { Artist.shared.galaxyPaint(p) }

    /// A star-forming knot: a pink bead in its own haze.
    private func knot(at centre: CGPoint, radius: CGFloat) {
        glow(at: centre, width: radius * 3.4, height: radius * 3.4, tilt: .zero,
             colour: paint(.nebula).1, peak: 0.7)
        fill(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                                    width: radius * 2, height: radius * 2)), paint(.nebula))
    }
}

import SwiftUI

// MARK: - Nebula glyphs
// Each named nebula's silhouette, drawn with the shared kit in
// `DeepSkyGlyph` (see `Artist+Nebulae` for the cast and colours).

// MARK: - NebulaShapes
enum NebulaShapes {

    enum Paint { case oxygen, ringRim, ringHole, owl, owlEye, halo, bowtie }

    /// The widest the silhouette reaches, in design units — fitted to the
    /// badge's frame.
    static func designSize(of nebula: NamedNebula) -> CGFloat {
        switch nebula {
        case .ring, .dumbbell:  return 14
        case .owl:              return 13
        case .littleDumbbell:   return 13
        }
    }

    // ▼ TWEAK how each sits ▼
    static let ringTilt:      Angle = .degrees(-28)
    static let dumbbellTilt:  Angle = .degrees(-18)
    static let bowtieTilt:    Angle = .degrees(38)
}

// MARK: - Drawing
extension GlyphPainter {

    mutating func draw(_ nebula: NamedNebula, fullDetail: Bool) {
        switch nebula {
        case .ring:           drawRing(fullDetail: fullDetail)
        case .owl:            drawOwl(fullDetail: fullDetail)
        case .dumbbell:       drawDumbbell(fullDetail: fullDetail)
        case .littleDumbbell: drawLittleDumbbell(fullDetail: fullDetail)
        }
    }

    private func paint(_ p: NebulaShapes.Paint) -> (Color, Color) { Artist.shared.nebulaPaint(p) }

    // MARK: Ring (M57)

    /// A donut, seen a little tilted: green-blue at its inner edge, amber,
    /// then red at the rim — and a dim hole, cased like Saturn's inner ring.
    private mutating func drawRing(fullDetail: Bool) {
        let tilt  = NebulaShapes.ringTilt
        let outer = ellipse(width: 14,  height: 11.2, tilt: tilt)
        let hole  = ellipse(width: 6.6, height: 5.0,  tilt: tilt)
        let oxy   = paint(.oxygen), rim = paint(.ringRim)

        caseOutline([outer])
        radialFill(outer, width: 14, height: 11.2, tilt: tilt,
                   stops: [(oxy.0, 0), (oxy.1, 0.46), (rim.1, 0.66), (rim.0, 1)])
        fill(hole, paint(.ringHole))
        glow(width: 5.4, height: 4.0, tilt: tilt, colour: oxy.1, peak: 0.35)
        stroke(hole, colour: casing, points: casingWidth * 0.45)
        if fullDetail {
            // The white dwarf that made it, in the middle of the hole.
            star(at: .zero, radius: 0.32)
        }
    }

    // MARK: Owl (M97)

    /// A round face lit from its middle, two dark eyes across it.
    private mutating func drawOwl(fullDetail: Bool) {
        let face = ellipse(width: 12.6, height: 12.0, tilt: .zero)
        let owl  = paint(.owl)

        caseOutline([face])
        radialFill(face, width: 12.6, height: 12.0, tilt: .zero,
                   stops: [(owl.1, 0), (owl.1.mix(with: owl.0, by: 0.35), 0.6), (owl.0, 1)])
        let eye = paint(.owlEye).0.opacity(0.85)
        blurred(radius: 0.3) {
            $0.shade($0.ellipse(at: CGPoint(x: -2.6, y: -0.5), width: 3.6, height: 4.6, tilt: .degrees(-15)), eye)
            $0.shade($0.ellipse(at: CGPoint(x:  2.6, y:  0.5), width: 3.6, height: 4.6, tilt: .degrees(-15)), eye)
        }
        if fullDetail {
            star(at: CGPoint(x: 0.1, y: 0), radius: 0.3)
        }
    }

    // MARK: Dumbbell (M27)

    /// The "apple core": a bright green hourglass, pinched at the waist,
    /// inside the fainter rosy oval — wider than it is tall, its "ears"
    /// filling the bites either side.
    private mutating func drawDumbbell(fullDetail: Bool) {
        let tilt     = NebulaShapes.dumbbellTilt
        let envelope = ellipse(width: 14, height: 11.6, tilt: tilt)
        let core     = dumbbellCore(tilt: tilt)
        let oxy      = paint(.oxygen), halo = paint(.halo)

        caseOutline([envelope])
        fill(envelope, halo)
        glow(width: 11, height: 9, tilt: tilt, colour: halo.1, peak: 0.5)
        radialFill(core, width: 9.4, height: 10.4, tilt: tilt,
                   stops: [(.white, 0), (oxy.1, 0.25), (oxy.0, 1)])
        if fullDetail {
            star(at: .zero, radius: 0.3)
        }
    }

    /// Two rounded fans meeting at the centre, opening up and down.
    private func dumbbellCore(tilt: Angle) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -0.9, y: 0))
        p.addQuadCurve(to: CGPoint(x: -3.4, y: -3.6), control: CGPoint(x: -2.8, y: -1.0))
        p.addQuadCurve(to: CGPoint(x:  3.4, y: -3.6), control: CGPoint(x:  0.0, y: -6.6))
        p.addQuadCurve(to: CGPoint(x:  0.9, y:  0),   control: CGPoint(x:  2.8, y: -1.0))
        p.addQuadCurve(to: CGPoint(x:  3.4, y:  3.6), control: CGPoint(x:  2.8, y:  1.0))
        p.addQuadCurve(to: CGPoint(x: -3.4, y:  3.6), control: CGPoint(x:  0.0, y:  6.6))
        p.addQuadCurve(to: CGPoint(x: -0.9, y:  0),   control: CGPoint(x: -2.8, y:  1.0))
        p.closeSubpath()
        return p.applying(CGAffineTransform(rotationAngle: tilt.radians))
    }

    // MARK: Little Dumbbell (M76)

    /// Two lobes tied at the waist, a hint of oxygen green where they meet;
    /// the faint loops either side only at pin size.
    private mutating func drawLittleDumbbell(fullDetail: Bool) {
        let tilt  = NebulaShapes.bowtieTilt
        let along = CGPoint(x: cos(tilt.radians) * 2.7, y: sin(tilt.radians) * 2.7)
        let lobes = [ellipse(at: CGPoint(x:  along.x, y:  along.y), width: 6.4, height: 5.0, tilt: tilt),
                     ellipse(at: CGPoint(x: -along.x, y: -along.y), width: 6.4, height: 5.0, tilt: tilt)]
        let bow   = paint(.bowtie)

        if fullDetail {
            // The faint outer loops, flung out across the bar.
            for side in [-1.0, 1.0] {
                let loop = arc(width: 9.0, height: 12.0, from: side > 0 ? -0.5 * .pi : 0.5 * .pi,
                               to: side > 0 ? 0.5 * .pi : 1.5 * .pi, tilt: tilt)
                    .applying(CGAffineTransform(translationX: CGFloat(side) * -sin(tilt.radians) * 0.8,
                                                y: CGFloat(side) * cos(tilt.radians) * 0.8))
                stroke(loop, colour: bow.1.opacity(0.45), width: 0.5)
            }
        }
        caseOutline(lobes)
        let bounds = lobes[0].boundingRect.union(lobes[1].boundingRect)
        for lobe in lobes { fill(lobe, bow, over: bounds) }
        glow(width: 4.4, height: 3.6, tilt: tilt, colour: paint(.oxygen).1, peak: 0.75)
    }
}

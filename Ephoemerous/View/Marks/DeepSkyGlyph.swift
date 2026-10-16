import SwiftUI

// MARK: - DeepSkyGlyph
// A deep-sky object that wears its own silhouette instead of its kind's
// badge — the six Local Group galaxies (`GalaxyGlyph`) and the named
// nebulae (`NebulaGlyph`). Each is a badge, not a replica: a few bold
// shapes from how the object really looks, cased like a spacecraft.
//
// Built the spacecraft way: every outer part's casing goes down first,
// then every fill, so overlapping parts read as ONE cased silhouette. The
// detail inside is uncased paint on top. The promoted pin (`fullDetail`)
// adds what only reads big.
//
// Geometry is in design units (`designSize`), screen terms: y down, north
// up, east left. A Canvas rasterises at its LAYOUT size, so callers enlarge
// it by laying it out bigger (`POILabelView.sizeScale`).
struct DeepSkyGlyph: View {

    let figure:     DeepSkyFigure
    let casing:     Color
    /// Casing weight, already scale-compensated by the caller.
    let lineWidth:  CGFloat
    let fullDetail: Bool
    /// Masked widget host: only alpha survives, so paint in white shades.
    let masked:     Bool

    /// Casing thickness as a multiple of the badge border — the spacecraft's.
    private static let casingWeight: CGFloat = 1.8

    /// The widest the silhouette reaches, in design units — fitted to the
    /// badge's frame.
    private var designSize: CGFloat {
        switch figure {
        case .galaxy(let g): return GalaxyShapes.designSize(of: g)
        case .nebula(let n): return NebulaShapes.designSize(of: n)
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let pad   = lineWidth * Self.casingWeight
            let k     = size.width / (designSize + pad)
            let place = CGAffineTransform(translationX: size.width / 2, y: size.height / 2).scaledBy(x: k, y: k)
            var painter = GlyphPainter(context: ctx, place: place, unit: k,
                                       casingWidth: pad, casing: casing, masked: masked)
            switch figure {
            case .galaxy(let g): painter.draw(g, fullDetail: fullDetail)
            case .nebula(let n): painter.draw(n, fullDetail: fullDetail)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - GlyphPainter
/// Draws one silhouette into a Canvas. Every path is built in design units
/// and placed by `place`; each object's drawing lives with its family
/// (`GalaxyGlyph`, `NebulaGlyph`).
struct GlyphPainter {

    var context:     GraphicsContext
    let place:       CGAffineTransform
    /// Points per design unit.
    let unit:        CGFloat
    let casingWidth: CGFloat
    let casing:      Color
    let masked:      Bool

    // MARK: Paint

    /// The silhouette's outline: every part's casing, under every fill.
    func caseOutline(_ parts: [Path]) {
        for part in parts {
            context.stroke(part.applying(place), with: .color(casing),
                           style: StrokeStyle(lineWidth: casingWidth, lineJoin: .round))
        }
    }

    /// A part in its paint (deep, bright), deep at the bottom → bright at
    /// the top of `bounds` — its own, unless it's one of several sharing a
    /// light. A masked host gets the same in white shades.
    func fill(_ path: Path, _ pair: (Color, Color), over bounds: CGRect? = nil) {
        let p    = masked ? (Color.white.opacity(0.4), Color.white.opacity(0.8)) : pair
        let rect = (bounds ?? path.boundingRect).applying(place)
        context.fill(path.applying(place),
                     with: .linearGradient(Gradient(colors: [p.0, p.1]),
                                           startPoint: CGPoint(x: rect.midX, y: rect.maxY),
                                           endPoint:   CGPoint(x: rect.midX, y: rect.minY)))
    }

    /// A part shaded from its centre outwards — `stops` run from the centre
    /// (0) to an ellipse `width` × `height` turned by `tilt` (1). For what
    /// glows from the middle: a ring nebula's inner edge, a lobe's root.
    func radialFill(_ path: Path, at centre: CGPoint = .zero, width: CGFloat, height: CGFloat,
                    tilt: Angle, stops: [(Color, CGFloat)]) {
        var layer = context
        layer.clip(to: path.applying(place))
        layer.concatenate(place)
        layer.translateBy(x: centre.x, y: centre.y)
        layer.rotate(by: tilt)
        layer.scaleBy(x: 1, y: height / width)
        let r = width / 2
        let g = Gradient(stops: stops.map { .init(color: masked ? .white.opacity(0.7) : $0.0, location: $0.1) })
        layer.fill(Path(ellipseIn: CGRect(x: -r * 2, y: -r * 2, width: r * 4, height: r * 4)),
                   with: .radialGradient(g, center: .zero, startRadius: 0, endRadius: r))
    }

    /// A soft elliptical light, `peak` opaque at its centre, gone at its rim.
    func glow(at centre: CGPoint = .zero, width: CGFloat, height: CGFloat,
              tilt: Angle, colour: Color, peak: Double) {
        let c = masked ? Color.white : colour
        var layer = context
        layer.concatenate(place)
        layer.translateBy(x: centre.x, y: centre.y)
        layer.rotate(by: tilt)
        layer.scaleBy(x: 1, y: height / width)
        let r = width / 2
        layer.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)),
                   with: .radialGradient(Gradient(stops: [.init(color: c.opacity(peak),        location: 0),
                                                          .init(color: c.opacity(peak * 0.7),  location: 0.45),
                                                          .init(color: c.opacity(0),           location: 1)]),
                                         center: .zero, startRadius: 0, endRadius: r))
    }

    /// One isophote: a smaller oval laid on the body in a brighter tint,
    /// `step` opaque — the bands stack into a stepped glow.
    func isophote(at centre: CGPoint = .zero, width: CGFloat, height: CGFloat, tilt: Angle,
                  colour: Color, step: Double) {
        context.fill(ellipse(at: centre, width: width, height: height, tilt: tilt).applying(place),
                     with: .color((masked ? .white : colour).opacity(step)))
    }

    /// A flat tint — dark detail (dust, an owl's eyes). Skipped on a masked
    /// host, where dark would come back as white.
    func shade(_ path: Path, _ colour: Color) {
        guard !masked else { return }
        context.fill(path.applying(place), with: .color(colour))
    }

    /// A star: a white point in a little light.
    func star(at centre: CGPoint, radius: CGFloat) {
        glow(at: centre, width: radius * 4, height: radius * 4, tilt: .zero, colour: .white, peak: 0.6)
        context.fill(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                                            width: radius * 2, height: radius * 2)).applying(place),
                     with: .color(.white))
    }

    /// A line `width` design units thick.
    func stroke(_ path: Path, colour: Color, width: CGFloat) {
        stroke(path, colour: colour, points: width * unit)
    }

    /// A line `points` thick, whatever the scale.
    func stroke(_ path: Path, colour: Color, points: CGFloat) {
        context.stroke(path.applying(place), with: .color(colour),
                       style: StrokeStyle(lineWidth: points, lineCap: .round))
    }

    /// Draws `body` through a blur of `radius` design units.
    func blurred(radius: CGFloat, _ body: (inout GlyphPainter) -> Void) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * unit))
            var inner = self
            inner.context = layer
            body(&inner)
        }
    }

    /// Draws `body` clipped to `path`.
    func clipped(to path: Path, _ body: (inout GlyphPainter) -> Void) {
        var inner = self
        inner.context.clip(to: path.applying(place))
        body(&inner)
    }

    // MARK: Shapes

    func ellipse(at centre: CGPoint = .zero, width: CGFloat, height: CGFloat, tilt: Angle) -> Path {
        Path(ellipseIn: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
            .applying(CGAffineTransform(rotationAngle: tilt.radians)
                .concatenating(CGAffineTransform(translationX: centre.x, y: centre.y)))
    }

    func capsule(at centre: CGPoint, length: CGFloat, thickness: CGFloat, tilt: Angle) -> Path {
        Path(roundedRect: CGRect(x: -length / 2, y: -thickness / 2, width: length, height: thickness),
             cornerRadius: thickness / 2)
            .applying(CGAffineTransform(rotationAngle: tilt.radians)
                .concatenating(CGAffineTransform(translationX: centre.x, y: centre.y)))
    }

    /// A band along a curve, `startWidth` thick at its root tapering to
    /// `endWidth` at its tip — an arm, a wing.
    func taperedBand(from a: CGPoint, control c: CGPoint, to b: CGPoint,
                     startWidth: CGFloat, endWidth: CGFloat) -> Path {
        func point(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
                           y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
        }
        var left = [CGPoint](), right = [CGPoint]()
        for i in 0...24 {
            let t      = CGFloat(i) / 24
            let p      = point(t)
            let ahead  = point(min(1, t + 0.01)), behind = point(max(0, t - 0.01))
            let dx     = ahead.x - behind.x, dy = ahead.y - behind.y
            let len    = max(0.0001, sqrt(dx * dx + dy * dy))
            let half   = (startWidth * (1 - t) + endWidth * t) / 2
            left.append(CGPoint(x: p.x - dy / len * half, y: p.y + dx / len * half))
            right.append(CGPoint(x: p.x + dy / len * half, y: p.y - dx / len * half))
        }
        var path = Path()
        path.addLines(left + right.reversed())
        path.closeSubpath()
        return path
    }

    /// Part of a centred ellipse's rim, from angle `from` to `to` (y down,
    /// so angles in 0…π run along its lower, nearer side).
    func arc(width: CGFloat, height: CGFloat, from: CGFloat, to: CGFloat, tilt: Angle) -> Path {
        var p = Path()
        for i in 0...32 {
            let t = from + (to - from) * CGFloat(i) / 32
            let pt = CGPoint(x: width / 2 * cos(t), y: height / 2 * sin(t))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p.applying(CGAffineTransform(rotationAngle: tilt.radians))
    }
}

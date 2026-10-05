import SwiftUI
import simd

// MARK: - SkyHeroScene
// The patch of sky a constellation or star hero shows, worked out once:
// every catalogue star near the focus, projected gnomonically onto the
// tangent plane (north up, east LEFT — the sky as you look up at it), plus
// the constellation's figure. Coordinates are in tangent units; the view
// fits them to whatever banner it gets.
struct SkyHeroScene {

    enum Focus {
        case constellation(Constellation)
        case star(Star)
        /// A body or craft: the sky around where it is right now, showing
        /// `halfField` (radians) above and below centre. The banner places
        /// the object itself at the centre.
        case point(SIMD3<Double>, halfField: Double)
    }

    struct Dot {
        let x, y:      Double
        let magnitude: Double
        let color:     Color
        let isFocus:   Bool
    }

    struct Line { let x1, y1, x2, y2: Double }

    let dots:   [Dot]
    let lines:  [Line]
    /// Half-extent the view must show, tangent units (x, y).
    let extent: (x: Double, y: Double)

    /// Faintest star drawn — near the naked-eye limit, so the patch looks
    /// like a dark-sky night rather than a chart.
    static let limitingMagnitude = 6.0

    init(focus: Focus) {
        let stars   = StarDatabase.shared.workableStars
        let figure  = Self.figureSegments(for: focus)
        let centre: SIMD3<Double>
        switch focus {
        case .star(let s):     centre = s.equatorialVector
        case .point(let v, _): centre = simd_normalize(v)
        case .constellation(let c):
            let pts = figure.flatMap { [$0.a.equatorialVector, $0.b.equatorialVector] }
            centre  = pts.isEmpty
                ? (stars.first { $0.constellation == c }?.equatorialVector ?? SIMD3(1, 0, 0))
                : simd_normalize(pts.reduce(.zero, +))
        }
        let east  = simd_normalize(simd_cross(SIMD3<Double>(0, 0, 1), centre))
        let north = simd_cross(centre, east)

        func project(_ v: SIMD3<Double>) -> (x: Double, y: Double)? {
            let d = simd_dot(v, centre)
            guard d > 0.2 else { return nil }                 // within ~78° of the focus
            return (-simd_dot(v, east) / d, simd_dot(v, north) / d)
        }

        let focusID: String? = { if case .star(let s) = focus { return s.id } else { return nil } }()
        dots = stars.compactMap { s in
            guard s.magnitude <= Self.limitingMagnitude, let p = project(s.equatorialVector) else { return nil }
            return Dot(x: p.x, y: p.y, magnitude: s.magnitude,
                       color: s.spectralClass.color, isFocus: s.id == focusID)
        }
        lines = figure.compactMap { seg in
            guard let a = project(seg.a.equatorialVector), let b = project(seg.b.equatorialVector) else { return nil }
            return Line(x1: a.x, y1: a.y, x2: b.x, y2: b.y)
        }

        // Frame the figure with a margin; a lone star gets a fixed ~24° patch,
        // a body the field its banner asks for.
        switch focus {
        case .star:
            extent = (tan(12 * Double.pi / 180), tan(12 * Double.pi / 180))
        case .point(_, let half):
            extent = (tan(half), tan(half))
        case .constellation:
            let xs = lines.flatMap { [abs($0.x1), abs($0.x2)] }
            let ys = lines.flatMap { [abs($0.y1), abs($0.y2)] }
            let minimum = tan(8 * Double.pi / 180)
            extent = (max(xs.max() ?? minimum, minimum) * 1.2, max(ys.max() ?? minimum, minimum) * 1.2)
        }
    }

    private static func figureSegments(for focus: Focus) -> [ConstellationLines.Segment] {
        switch focus {
        case .constellation(let c): return ConstellationLines.shared.segments[c] ?? []
        case .star(let s):          return ConstellationLines.shared.segments[s.constellation] ?? []
        // A body belongs to no figure: draw every figure in its patch, so
        // you can see which constellation it's passing through.
        case .point:                return ConstellationLines.shared.segments.values.flatMap { $0 }
        }
    }
}

// MARK: - SkyHeroView
// The hero for every object, drawn from the app's own star
// catalogue rather than fetched: true star colours from the spectral class,
// size and glow from magnitude, the figure laid faintly over it. A star's
// hero centres on the star and gives it a soft halo; a planet's or a
// spacecraft's centres on where it is now (see `HeroBanner` for what sits
// at the centre). Free, offline, one look everywhere.
struct SkyHeroView: View {

    let scene: SkyHeroScene
    /// Paint the hero's own night behind the stars. Off where the picture
    /// sits on the sheet's sky instead (the place header) — a ground of its
    /// own there boxed the figure in a rectangle of a different colour.
    var ground: Bool = true

    init(focus: SkyHeroScene.Focus, ground: Bool = true) {
        scene       = SkyHeroScene(focus: focus)
        self.ground = ground
    }

    var body: some View {
        Canvas { ctx, size in
            // Fit the scene's extent to the banner, whichever axis binds.
            let k  = min(size.width / (2 * scene.extent.x), size.height / (2 * scene.extent.y))
            let cx = size.width / 2, cy = size.height / 2
            func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: cx + x * k, y: cy - y * k) }

            // Figure first, so stars sit on top of their own lines.
            var figure = Path()
            for l in scene.lines {
                figure.move(to: point(l.x1, l.y1)); figure.addLine(to: point(l.x2, l.y2))
            }
            ctx.stroke(figure, with: .color(.white.opacity(0.22)), lineWidth: 1)

            for dot in scene.dots {
                let p = point(dot.x, dot.y)
                guard p.x > -20, p.x < size.width + 20, p.y > -20, p.y < size.height + 20 else { continue }
                let r = Self.radius(for: dot.magnitude)
                if dot.magnitude < 2.5 || dot.isFocus {
                    let glow = r * (dot.isFocus ? 7 : 4)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - glow, y: p.y - glow, width: glow * 2, height: glow * 2)),
                             with: .radialGradient(Gradient(colors: [dot.color.opacity(dot.isFocus ? 0.55 : 0.35), .clear]),
                                                   center: p, startRadius: 0, endRadius: glow))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(dot.color.opacity(Self.opacity(for: dot.magnitude))))
            }
        }
        .background { if ground { Artist.shared.skyHeroGround } }
    }

    /// Dot radius from magnitude: the brightest stars ~3pt, the limit ~0.5pt.
    private static func radius(for magnitude: Double) -> CGFloat {
        CGFloat(max(0.5, (SkyHeroScene.limitingMagnitude + 0.5 - magnitude) * 0.42))
    }

    /// Faint stars fade rather than shrink below a pixel.
    private static func opacity(for magnitude: Double) -> Double {
        min(1, max(0.35, (SkyHeroScene.limitingMagnitude + 1 - magnitude) / 4))
    }
}

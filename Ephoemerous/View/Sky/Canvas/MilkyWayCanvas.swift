import SwiftUI
import simd

// MARK: - MilkyWayCanvas
// The Milky Way drawn as what it is — a great many faint stars. A fixed
// stipple of tiny dots, scattered once along the galactic plane with a
// density that follows the galaxy: thin toward the anticentre in Auriga,
// rich through Cygnus and Carina, and gathered into a bright bulge round
// the centre in Sagittarius. The Great Rift, the dark lane from Aquila up
// through Cygnus, is thinned out of it.
//
// Procedural: `Profile` sets the density, and the dots are drawn from it
// once with a fixed seed, so the band is the same every launch. Points
// suit the projection where filled shapes didn't — stereographic stretches
// the sky toward the nadir without limit, and dots there simply spread
// apart. Three paths, one per brightness, at the committed camera like the
// grid — frozen through gestures, redrawn at a settle.
//
// Two styles while we compare them on the device: the stipple, and
// ENGRAVED — the same density traced as hairline isophotes, the contour
// lines of an old star atlas. Engraved is the default; launch with
// `-milkyWay stipple` for the dots.
struct MilkyWayCanvas: View, Equatable {
    let camera: SkyCamera

    enum Style { case engraved, stipple }

    static let style: Style = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-milkyWay"), i + 1 < args.count else { return .engraved }
        return args[i + 1] == "stipple" ? .stipple : .engraved
    }()

    /// The isophotes: dots of the star colour, this wide, this far apart;
    /// and each level's fill, which stacks toward the core. ▼ TWEAK ▼
    private static let lineOpacity: Double  = 0.55
    private static let lineWidth:   CGFloat = 1.3
    private static let dotGap:      CGFloat = 3.2
    private static let fillOpacity: Double  = 0.018

    /// Each brightness tier's opacity of the star colour. ▼ TWEAK ▼
    private static let tierOpacity: [Double] = [0.16, 0.28, 0.45]

    /// Dot side, in points. ▼ TWEAK ▼
    private static let dotSize: CGFloat = 1.1

    var body: some View {
        Group {
            switch Self.style {
            case .engraved: engraved
            case .stipple:  stipple
            }
        }
        .allowsHitTesting(false)
    }

    /// The fill first, a barely-there tone a level, then every contour
    /// in one dotted path — dotted, so they never read as constellation
    /// lines. A step torn across the nadir breaks the line there.
    private var engraved: some View {
        Canvas { ctx, _ in
            let star = Artist.shared.starColor
            ctx.drawLayer { fill in
                fill.addFilter(.blur(radius: 3))
                for quads in Isophotes.fills {
                    var path = Path()
                    for quad in quads {
                        let ps = quad.compactMap { camera.screen(equatorial: $0) }
                        guard ps.count == 4, Self.intact(ps) else { continue }
                        path.addLines(ps)
                        path.closeSubpath()
                    }
                    fill.fill(path, with: .color(star.opacity(Self.fillOpacity)))
                }
            }
            var path = Path()
            for line in Isophotes.lines {
                var prev: CGPoint?
                for v in line {
                    guard let p = camera.screen(equatorial: v) else { prev = nil; continue }
                    if let q = prev, Self.intact([q, p]) { path.addLine(to: p) }
                    else                                 { path.move(to: p) }
                    prev = p
                }
            }
            ctx.stroke(path,
                       with: .color(star.opacity(Self.lineOpacity)),
                       style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round,
                                          dash: [0.01, Self.dotGap]))
        }
    }

    private static func intact(_ ps: [CGPoint]) -> Bool {
        for i in ps.indices {
            let a = ps[i], b = ps[(i + 1) % ps.count]
            let dx = a.x - b.x, dy = a.y - b.y
            if dx * dx + dy * dy > 90_000 { return false }
        }
        return true
    }

    private var stipple: some View {
        Canvas { ctx, _ in
            let star = Artist.shared.starColor
            var paths = Array(repeating: Path(), count: Self.tierOpacity.count)
            let d = Self.dotSize, h = d / 2
            for dot in Stipple.dots {
                guard let p = camera.screen(equatorial: dot.vector) else { continue }
                paths[dot.tier].addRect(CGRect(x: p.x - h, y: p.y - h, width: d, height: d))
            }
            for (tier, path) in paths.enumerated() {
                ctx.fill(path, with: .color(star.opacity(Self.tierOpacity[tier])))
            }
        }
    }

    // MARK: Fade

    /// Strongest with the whole sky in view, gone once the screen spans
    /// less than a fifth of it — zoomed in, the stipple would only read as
    /// dust between real stars. `span` is the screen's shorter side in
    /// projection units (about 4 at home).
    static func reveal(span: Double) -> Double {
        let t = (span - 0.8) / (2.2 - 0.8)
        let c = min(max(t, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Isophotes
// The band's density traced at a few levels by marching squares over a
// galactic (l, b) grid, once, chained into lines and kept on the sphere —
// so the projection bends them like any other line on the sky. The same
// grid's cells, above each level, make the barely-there fill.
private enum Isophotes {
    /// Density levels, faint to bright. ▼ TWEAK ▼
    static let levels: [Double] = [0.15, 0.4, 0.7]
    /// Cloudiness the contours follow — little, so they don't wander.
    private static let clumps: Double = 0.06

    private static let stepL: Double = 1, stepB: Double = 0.5, maxB: Double = 32
    private static var nl: Int { Int(360 / stepL) }
    private static var nb: Int { Int(2 * maxB / stepB) }
    private static func lAt(_ i: Int) -> Double { Double(i) * stepL }
    private static func bAt(_ j: Int) -> Double { -maxB + Double(j) * stepB }

    private static let grid: [[Double]] = {
        (0...nl).map { i in (0...nb).map { j in Profile.density(l: lAt(i % nl), b: bAt(j), clumps: clumps) } }
    }()

    /// The contours, as polylines of sky vectors.
    static let lines: [[SIMD3<Double>]] = {
        var out: [[SIMD3<Double>]] = []
        for level in levels {
            for chain in chains(segments(at: level)) {
                out.append(chain.map { Galactic.equatorial(l: $0.l, b: $0.b) })
            }
        }
        return out
    }()

    /// The fill: for each level, the grid cells whose centre is above it,
    /// as quads of sky vectors. Two-degree cells — the fill is soft, it
    /// doesn't need the contours' grain.
    static let fills: [[[SIMD3<Double>]]] = {
        levels.map { level in
            var quads: [[SIMD3<Double>]] = []
            for i in stride(from: 0, to: nl, by: 2) {
                for j in stride(from: 0, to: nb, by: 2) {
                    let v = (grid[i][j] + grid[i + 2][j] + grid[i][j + 2] + grid[i + 2][j + 2]) / 4
                    guard v > level else { continue }
                    quads.append([(i, j), (i + 2, j), (i + 2, j + 2), (i, j + 2)].map {
                        Galactic.equatorial(l: lAt($0.0), b: bAt($0.1))
                    })
                }
            }
            return quads
        }
    }()

    private struct P: Hashable {
        let l, b: Double
        var key: P { P(l: (l * 1e5).rounded() / 1e5, b: (b * 1e5).rounded() / 1e5) }
    }

    private static func segments(at level: Double) -> [(P, P)] {
        var out: [(P, P)] = []
        for i in 0..<nl {
            for j in 0..<nb {
                // Corners anticlockwise from (l, b): a b c d; edges ab bc cd da.
                let c = [(lAt(i), bAt(j), grid[i][j]),         (lAt(i + 1), bAt(j), grid[i + 1][j]),
                         (lAt(i + 1), bAt(j + 1), grid[i + 1][j + 1]), (lAt(i), bAt(j + 1), grid[i][j + 1])]
                var hits: [P] = []
                for e in 0..<4 {
                    let (l0, b0, v0) = c[e], (l1, b1, v1) = c[(e + 1) % 4]
                    guard (v0 > level) != (v1 > level) else { continue }
                    let t = (level - v0) / (v1 - v0)
                    hits.append(P(l: l0 + (l1 - l0) * t, b: b0 + (b1 - b0) * t).key)
                }
                if hits.count == 2 { out.append((hits[0], hits[1])) }
                else if hits.count == 4 {
                    // Saddle: the centre decides which corners the lines
                    // cut off. Centre on a's side → cut off b and d.
                    let centre = c.map(\.2).reduce(0, +) / 4
                    if (centre > level) == (c[0].2 > level) { out += [(hits[0], hits[1]), (hits[2], hits[3])] }
                    else                                     { out += [(hits[3], hits[0]), (hits[1], hits[2])] }
                }
            }
        }
        return out
    }

    /// Join segments end to end into polylines, so a dash runs evenly
    /// along a whole contour instead of restarting every cell.
    private static func chains(_ segs: [(P, P)]) -> [[P]] {
        var at: [P: [Int]] = [:]
        for (k, s) in segs.enumerated() { at[s.0, default: []].append(k); at[s.1, default: []].append(k) }
        var used = [Bool](repeating: false, count: segs.count)
        var out: [[P]] = []
        func extend(_ chain: inout [P]) {
            while let end = chain.last,
                  let k = at[end]?.first(where: { !used[$0] }) {
                used[k] = true
                chain.append(segs[k].0 == end ? segs[k].1 : segs[k].0)
            }
        }
        for k in segs.indices where !used[k] {
            used[k] = true
            var forward = [segs[k].0, segs[k].1]
            extend(&forward)
            var backward = [segs[k].0]
            extend(&backward)
            out.append(backward.reversed().dropLast() + forward)
        }
        return out
    }
}

// MARK: - Stipple
// The dots, scattered once by rejection against `Profile.density`.
private enum Stipple {
    struct Dot {
        let vector: SIMD3<Double>
        let tier:   Int
    }

    /// How many dots make the whole band. ▼ TWEAK ▼
    static let count = 24_000

    static let dots: [Dot] = {
        var rng   = SplitMix(seed: 0x6D696C6B79)
        var dots  = [Dot]()
        dots.reserveCapacity(count)
        var tries = 0
        while dots.count < count, tries < count * 40 {
            tries += 1
            let l = rng.unit() * 360
            let b = (rng.unit() * 2 - 1) * 32
            let f = Profile.density(l: l, b: b)
            guard rng.unit() < f else { continue }
            // Brighter where the band is dense, with scatter, so the
            // core glows without every dot in it being bright.
            let lift = min(1, f + 0.35 * (rng.unit() - 0.5))
            let tier = lift > 0.7 ? 2 : lift > 0.4 ? 1 : 0
            dots.append(Dot(vector: Galactic.equatorial(l: l, b: b), tier: tier))
        }
        return dots
    }()

    /// A small, fixed-seed generator — the band must not reshuffle.
    struct SplitMix {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    }
}

// MARK: - Profile
// The band's density, 0…1, over galactic longitude l (degrees, 0 = the
// centre in Sagittarius, 90 = Cygnus, 180 = the anticentre in Auriga) and
// latitude b. Rough by design — a chart's band, not a survey's.
private enum Profile {

    /// `clumps` is how much cloudiness rides on the band: the stipple
    /// wants it, the isophotes want almost none or they wander.
    static func density(l: Double, b: Double, clumps: Double = 0.22) -> Double {
        let d      = fromCentre(l)
        let rich   = g(d, 85)                       // the bright half
        let bulge  = g(d, 16)                       // Sagittarius–Scorpius
        let cygnus = g(l - 78, 18)                  // the Cygnus star cloud
        let carina = g(l - 288, 14)                 // Carina–Crux
        let c      = centre(l: l)
        let sigma  = 3.5 + 3 * rich + 4 * bulge
        let glow   = 0.16 + 0.3 * rich + 0.25 * cygnus + 0.2 * carina
        var f      = glow * g(b - c, sigma)
        // The bulge: a round swelling on the centre, taller than the band.
        f += 0.95 * bulge * g(b + 1, 7)
        // A little clumping, so the band has clouds rather than a gradient.
        f *= 1 - clumps + clumps * sin(l * 0.41) * sin(b * 0.9 + l * 0.17)
        return min(1, f * (1 - rift(l: l, b: b)))
    }

    /// Distance from the galactic centre in longitude, 0…180.
    private static func fromCentre(_ l: Double) -> Double {
        let d = l.truncatingRemainder(dividingBy: 360)
        return min(abs(d), 360 - abs(d))
    }

    /// A gaussian of width `w`, 1 at zero.
    private static func g(_ x: Double, _ w: Double) -> Double { exp(-0.5 * (x / w) * (x / w)) }

    /// The band's spine. It rises a little north through Cygnus and dips
    /// south through Carina–Crux, where the bright clouds lie off the plane.
    private static func centre(l: Double) -> Double {
        1.5 * sin(l * .pi / 180) - 1.0 * exp(-pow((l - 300) / 25, 2))
    }

    /// The Great Rift — from the bulge's edge (l ≈ 10°) up through Aquila
    /// to Cygnus (l ≈ 86°), a little north of the spine, widest in Aquila.
    /// How much of the band it takes out, 0…0.9.
    private static func rift(l: Double, b: Double) -> Double {
        let t = (l - 10) / 76
        guard t > 0, t < 1 else { return 0 }
        // Fades in and out by DEPTH, not width: a rift that narrowed to a
        // needle at its ends drew every contour into a fan at its tip.
        let s = sin(t * .pi)
        return 0.85 * s * s * g(b - centre(l: l) - 1.2, 1.4 + 0.8 * s)
    }
}

// MARK: - Galactic
private enum Galactic {
    // The north galactic pole and the galactic longitude of the north
    // celestial pole, J2000 (IAU 1958, as restated for J2000).
    private static let poleRA:  Double = 192.85948 * .pi / 180
    private static let poleDec: Double =  27.12825 * .pi / 180
    private static let ncpL:    Double = 122.93192 * .pi / 180

    /// Unit equatorial vector for galactic (l, b), both in degrees.
    static func equatorial(l: Double, b: Double) -> SIMD3<Double> {
        let lr = l * .pi / 180, br = b * .pi / 180
        let dl = ncpL - lr
        let sinDec = sin(br) * sin(poleDec) + cos(br) * cos(poleDec) * cos(dl)
        let dec    = asin(max(-1, min(1, sinDec)))
        let ra     = poleRA + atan2(cos(br) * sin(dl),
                                    sin(br) * cos(poleDec) - cos(br) * sin(poleDec) * cos(dl))
        return Precession.equatorialVector(ra: .radians(ra), dec: .radians(dec))
    }
}

#if DEBUG
#Preview("Milky Way") {
    PreviewSky.night { MilkyWayCanvas(camera: PreviewSky.camera) }
}
#endif

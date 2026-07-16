import WidgetKit
import SwiftUI
import LoreKit
import simd

// MARK: - OrlojWidget
// The Prague astronomical clock, superimposed on the app's REAL NorthOUT
// projection — not a lookalike drawing, the SAME projection. NorthOUT's
// scale derivation already uses ρ = 2·tan((δ+90°)/2) for a declination
// circle (see EAppState+Space.northOutDefaultScale); that is EXACTLY
// DeprecationStation/Orloj/EOrlojGeometry's own r = tan(45°+δ/2) formula.
// The Orloj and NorthOUT are the same stereographic projection from the
// celestial north pole (eye = NCP, tangent plane = SCP) — one was built
// for a 1410 astrolabe, the other for this app; they were always the
// same math. Everything here is SAMPLED through the real `SkyCamera`
// (the codebase's established pattern — CelestialGridCanvas,
// AlmucantarCurve), so it's exact for the viewer's actual latitude with
// no separate handedness reasoning.
//
// RENDERING: `OrlojFace` VENDS PATHS; the view composes them as SwiftUI
// Shape layers (only the star field stays a Canvas). This is deliberate:
// Shape views can carry materials, and the two elements with real BODY —
// the outer dial band, the zodiac band — wear a hand-rolled glass look
// (`.glassEffect` doesn't render in the widget process; the faux
// gradient-sheen recipe rasterises anywhere). The hairline geometry
// stays tinted strokes riding on top, exactly the real instrument's
// construction: gold filigree on solid rings. When this face graduates
// into the app, the same band shapes take a real `.glassEffect(in:)`.
struct OrlojProvider: TimelineProvider {

    func placeholder(in context: Context) -> OrlojEntry {
        OrlojEntry(date: .now, origin: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (OrlojEntry) -> Void) {
        Task { @MainActor in
            completion(OrlojEntry(date: .now, origin: FavouritesStore().observerOrigin()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OrlojEntry>) -> Void) {
        Task { @MainActor in
            let origin = FavouritesStore().observerOrigin()
            let now    = Date.now
            // 15-minute beats — the hands and unequal-hour arcs visibly
            // advance between refreshes, like the real clock's mechanism.
            let entries = stride(from: 0, through: 60, by: 15).map { m in
                OrlojEntry(date: now.addingTimeInterval(Double(m) * 60), origin: origin)
            }
            completion(Timeline(entries: entries,
                                policy: .after(now.addingTimeInterval(75 * 60))))
        }
    }
}

struct OrlojEntry: TimelineEntry {
    let date:   Date
    /// Observer origin the app last parked at — nil before the app has
    /// ever backgrounded; falls back to Prague itself, fittingly.
    let origin: (latDeg: Double, lonDeg: Double)?
}

// MARK: - OrlojFace
// Builds the NorthOUT camera and vends every layer of the astrolabe as
// a `Path` in widget coordinates. Pure geometry — no drawing, no style;
// the view decides what's glass, what's filigree.
private struct OrlojFace {

    let camera:   SkyCamera
    let date:     Date
    let lst:      Angle
    let latitude: Angle

    /// Declinations the decorative rings sit at — outside the Tropic of
    /// Cancer plate, Roman dial the outermost. ▼ TWEAK ring spacing ▼
    static let romanDialDec    = AstroConstants.tropicCancer + .degrees(12)
    static let bohemianRingDec = AstroConstants.tropicCancer + .degrees(6)

    @MainActor
    init(date: Date, origin: (latDeg: Double, lonDeg: Double)?, size: CGSize) {
        self.date = date
        // Prague fallback before the app has ever backgrounded — apt for
        // the one widget that's explicitly styled after this city's clock.
        let lat = Angle.degrees(origin?.latDeg ?? 50.09)
        let lon = Angle.degrees(origin?.lonDeg ?? 14.42)
        latitude = lat
        lst = EPrecession.lst(for: date, longitude: lon)

        let viewpoint = EProjection.Viewpoint(
            originVector: Angle.spherePoint(latitude: lat, longitude: lon),
            planeVector:  Angle.spherePoint(latitude: .radians(-lat.radians),
                                            longitude: lon + .radians(.pi)),
            morph: 1)   // pure NorthOUT — this IS the astrolabe's projection

        // ▼ TWEAK the dial size here — fit the Roman dial ring within
        // ~46% of the shorter side. Solved directly (radius is linear in
        // scale). NOTE the factor 2: EProjection's stereographic puts a
        // declination circle at ρ = 2·tan(45°+δ/2) projection units —
        // the same 2 as northOutDefaultScale's derivation. ▼
        let targetOuterRadius = min(size.width, size.height) * 0.46
        let romanRho = 2 * tan(.pi / 4 + Self.romanDialDec.radians / 2)
        let scale = targetOuterRadius / CGFloat(romanRho)

        // The face must stand STILL — meridian vertical, noon at top,
        // the sky rotating over it (dial fixed, rete turns — the real
        // mechanism). At morph 1 the screen basis is the pole fallback
        // (arbitrary phase, and LST-dependent through `sidereal`), so:
        // project a probe at H = 0 (upper meridian, RA = LST) with an
        // unrotated camera, measure where it landed, and set the camera
        // rotation that carries it straight UP.
        let sidereal = Angle.radians(-lst.radians)
        let unrotated = SkyCamera(scale: scale, offset: .zero, size: size,
                                 viewpoint: viewpoint, sidereal: sidereal)
        var rotation = Angle.zero
        let c = unrotated.screen(.zero)
        if let probe = unrotated.screen(
            equatorial: EPrecession.equatorialVector(ra: lst, dec: .zero)) {
            let theta = atan2(Double(probe.y - c.y), Double(probe.x - c.x))
            rotation = .radians(-Double.pi / 2 - theta)
        }

        camera = SkyCamera(scale: scale, offset: .zero, rotation: rotation,
                          size: size, viewpoint: viewpoint, sidereal: sidereal)
    }

    var center: CGPoint { camera.screen(.zero) }

    // MARK: Star field (stays Canvas-drawn — hundreds of dots, no glass)

    /// Faint naked-eye field — kept sparse (mag ≤ 3.6) so the dial
    /// geometry stays the thing you actually read.
    @MainActor
    func drawStars(in ctx: inout GraphicsContext, size: CGSize) {
        for star in StarDatabase.shared.workableStars where star.magnitude <= 3.6 {
            guard let sc = camera.screen(equatorial: star.equatorialVector),
                  sc.x > -4, sc.x < size.width + 4,
                  sc.y > -4, sc.y < size.height + 4 else { continue }
            let r = max(0.6, 1.8 - 0.35 * star.magnitude)
            ctx.fill(circle(sc, r), with: .color(.white.opacity(0.5)))
        }
    }

    // MARK: Plate (fixed)

    /// Tropic of Capricorn (inner), equator, Tropic of Cancer (outer) —
    /// each with its stroke weight, the equator emphasised.
    @MainActor
    func platePaths() -> [(path: Path, width: CGFloat)] {
        [(sampledParallel(declination: AstroConstants.tropicCapricorn), 1.0),
         (sampledParallel(declination: .zero),                          1.6),
         (sampledParallel(declination: AstroConstants.tropicCancer),    1.0)]
    }

    /// The horizon — altitude = 0 around the OBSERVER's zenith (not the
    /// pole), clipped to the Tropic of Cancer like the real tympan.
    @MainActor
    func horizonPath() -> Path {
        let clip = radiusForDeclination(AstroConstants.tropicCancer) * 1.02
        var path = Path()
        var started = false
        for i in 0...160 {
            let t = Double(i) / 160
            let q = camera.viewpoint.skyPoint(altitude: .zero, at: t)
            if let sc = camera.screen(rotatedEquatorial: q),
               hypot(sc.x - center.x, sc.y - center.y) <= clip {
                if started { path.addLine(to: sc) } else { path.move(to: sc); started = true }
            } else {
                started = false
            }
        }
        return path
    }

    /// Unequal (planetary) hours: the day arc between sunrise and sunset,
    /// split into 12, one curved line per hour fitted through its point
    /// on all three plate circles. Merged into one path — one stroke.
    @MainActor
    func unequalHoursPath() -> Path {
        let decs: [Angle] = [AstroConstants.tropicCancer, .zero, AstroConstants.tropicCapricorn]
        var merged = Path()
        for k in 0...12 {
            let frac = Double(k) / 12
            var pts: [CGPoint] = []
            for dec in decs {
                guard let hSet = Self.sunsetHourAngle(declination: dec, latitude: latitude)
                else { continue }
                let H = -hSet + frac * 2 * hSet
                if let sc = ringPoint(hourAngle: H, declination: dec) { pts.append(sc) }
            }
            guard pts.count >= 2 else { continue }
            if pts.count == 3, let cir = Self.circle(through: pts[0], pts[1], pts[2]) {
                merged.addPath(Self.arcPolyline(centre: cir.centre, radius: cir.radius,
                                               from: pts[0], through: pts[1], to: pts[2]))
            } else {
                merged.move(to: pts.first!)
                merged.addLine(to: pts.last!)
            }
        }
        return merged
    }

    // MARK: Dial rings (fixed)

    /// The outer dial as a GLASS BAND: annulus from just inside the
    /// Old-Bohemian ring to just outside the Roman dial — the real
    /// clock's single black ring that carries both scales. Even-odd.
    /// ▼ TWEAK the band edges here ▼
    @MainActor
    func dialBandPath() -> Path {
        let outer = radiusForDeclination(Self.romanDialDec) + 5
        let inner = radiusForDeclination(Self.bohemianRingDec) - 11
        var path = circle(center, outer)
        path.addPath(circle(center, inner))
        return path
    }

    /// A plain circle outline at a ring's declination.
    @MainActor
    func ringCirclePath(declination dec: Angle) -> Path {
        circle(center, radiusForDeclination(dec))
    }

    /// Hour ticks for a ring — Roman dial (offset 0, long tick every 6)
    /// and Old-Bohemian ring (offset by sunset hour angle, one long tick
    /// at 0/24) are the same construction, different phase and rhythm.
    /// Ticks are PROJECTED (RA = LST − H, like a star) — they carry the
    /// meaning, they must land where the Sun hand actually crosses.
    @MainActor
    func ringTicksPath(declination dec: Angle, hourOffset: Double,
                       tickLength: CGFloat, longEvery: Int) -> Path {
        var merged = Path()
        for h in 0..<24 {
            let H = hourOffset + Double(h) / 24 * 2 * .pi
            guard let p = ringPoint(hourAngle: H, declination: dec) else { continue }
            let long = (h % longEvery == 0) ? tickLength * 1.6 : tickLength
            merged.addPath(tick(at: p, length: long))
        }
        return merged
    }

    /// Sunset hour angle for TODAY's sun — the Old-Bohemian ring's phase.
    var bohemianOffset: Double? {
        Self.sunsetHourAngle(declination: sunDec, latitude: latitude)
    }

    // MARK: Rete (rotates with the sky)

    /// The ecliptic circle — the zodiac ring's centreline.
    @MainActor
    func zodiacLinePath() -> Path {
        var path = Path()
        var started = false
        for i in 0...160 {
            let t = Double(i) / 160
            let q = SIMD3<Double>.eclipticPoint(lambda: .radians(t * 2 * .pi))
            if let sc = camera.screen(equatorial: q) {
                if started { path.addLine(to: sc) } else { path.move(to: sc); started = true }
            } else {
                started = false
            }
        }
        return path
    }

    /// The zodiac as a GLASS BAND — the ecliptic line swollen into a
    /// fillable region. `strokedPath` turns any centreline into a band,
    /// which is exactly what the real rete is: a solid ring whose
    /// centreline is the ecliptic. ▼ TWEAK the band width here ▼
    @MainActor
    func zodiacBandPath(width: CGFloat = 14) -> Path {
        zodiacLinePath().strokedPath(StrokeStyle(lineWidth: width,
                                                 lineCap: .round, lineJoin: .round))
    }

    /// 12 sign-boundary ticks, pointing toward the pole centre.
    @MainActor
    func zodiacTicksPath() -> Path {
        var merged = Path()
        for i in 0..<12 {
            guard let p = camera.screen(
                equatorial: .eclipticPoint(lambda: .degrees(Double(i) * 30)))
            else { continue }
            merged.addPath(tick(at: p, length: 8))
        }
        return merged
    }

    // MARK: Hands

    @MainActor var sunPoint: CGPoint? {
        camera.screen(equatorial: .eclipticPoint(lambda: sunLambda))
    }

    @MainActor var moonPoint: CGPoint? {
        let (vec, _, _) = EMoonPosition.vector(for: date, siderealOffset: camera.sidereal)
        return camera.screen(rotatedEquatorial: vec)
    }

    func handPath(to p: CGPoint) -> Path {
        var hand = Path()
        hand.move(to: center)
        hand.addLine(to: p)
        return hand
    }

    func markerPath(at p: CGPoint, radius: CGFloat) -> Path {
        circle(p, radius)
    }

    // MARK: Sun helpers

    private var sunLambda: Angle { ESunPosition.eclipticLongitude(for: date) }
    private var sunDec:    Angle { ESunPosition.equatorialCoords(lambda: sunLambda).dec }

    // MARK: Sampling helpers

    /// A full constant-declination circle, RA swept 0…2π.
    @MainActor
    private func sampledParallel(declination dec: Angle, steps: Int = 120) -> Path {
        var path = Path()
        var started = false
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let q = EPrecession.equatorialVector(ra: .radians(t * 2 * .pi), dec: dec)
            if let sc = camera.screen(equatorial: q) {
                if started { path.addLine(to: sc) } else { path.move(to: sc); started = true }
            } else {
                started = false
            }
        }
        return path
    }

    /// A point at hour angle H (from the CURRENT meridian) and
    /// declination dec — built exactly like a star (RA = LST − H, then
    /// the normal equatorial→screen pipeline), so it's internally
    /// consistent with every other hour-angle element by construction.
    @MainActor
    private func ringPoint(hourAngle H: Double, declination dec: Angle) -> CGPoint? {
        let q = EPrecession.equatorialVector(ra: .radians(lst.radians - H), dec: dec)
        return camera.screen(equatorial: q)
    }

    /// Closed-form declination-circle radius — valid ONLY as a
    /// rotation-agnostic distance-from-centre (clipping thresholds,
    /// plain circle outlines), never for placing a specific point.
    /// ρ = 2·tan(45°+δ/2) — the 2 is EProjection's convention.
    private func radiusForDeclination(_ dec: Angle) -> CGFloat {
        camera.scale * CGFloat(2 * tan(.pi / 4 + dec.radians / 2))
    }

    // MARK: Pure geometry (mirrors EOrlojGeometry / OrlojUnequalHoursLayer,
    // duplicated locally so this file has no DeprecationStation dependency)

    /// Hour angle of sunset for a given declination: cos H = −tanφ·tanδ.
    /// nil during polar day / night.
    private static func sunsetHourAngle(declination dec: Angle, latitude lat: Angle) -> Double? {
        let c = -tan(lat.radians) * tan(dec.radians)
        guard c >= -1, c <= 1 else { return nil }
        return acos(c)
    }

    /// Circle through three points, or nil if (near) collinear.
    private static func circle(through a: CGPoint, _ b: CGPoint, _ c: CGPoint)
        -> (centre: CGPoint, radius: CGFloat)? {
        let d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
        guard abs(d) > 1e-6 else { return nil }
        let a2 = a.x * a.x + a.y * a.y
        let b2 = b.x * b.x + b.y * b.y
        let c2 = c.x * c.x + c.y * c.y
        let ux = (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d
        let uy = (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d
        let centre = CGPoint(x: ux, y: uy)
        return (centre, hypot(a.x - ux, a.y - uy))
    }

    /// Polyline along the circle arc from `a` to `b`, taking the side
    /// that passes through `mid`.
    private static func arcPolyline(centre o: CGPoint, radius r: CGFloat,
                                    from a: CGPoint, through mid: CGPoint,
                                    to b: CGPoint) -> Path {
        func angle(_ p: CGPoint) -> Double { atan2(Double(p.y - o.y), Double(p.x - o.x)) }
        func norm(_ x: Double) -> Double {
            let t = x.truncatingRemainder(dividingBy: 2 * .pi)
            return t < 0 ? t + 2 * .pi : t
        }
        let aA = angle(a), aM = angle(mid), aB = angle(b)
        var sweep = norm(aB - aA)
        let toMid = norm(aM - aA)
        if toMid > sweep { sweep -= 2 * .pi }

        var path = Path()
        let steps = 24
        for i in 0...steps {
            let t = aA + sweep * Double(i) / Double(steps)
            let p = CGPoint(x: o.x + r * CGFloat(cos(t)), y: o.y + r * CGFloat(sin(t)))
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        return path
    }

    /// Inward tick from `point` toward the plate centre.
    private func tick(at point: CGPoint, length: CGFloat) -> Path {
        let dx = center.x - point.x, dy = center.y - point.y
        let len = max(hypot(dx, dy), 0.0001)
        let inner = CGPoint(x: point.x + dx / len * length, y: point.y + dy / len * length)
        var p = Path()
        p.move(to: point)
        p.addLine(to: inner)
        return p
    }

    private func circle(_ centre: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                              width: radius * 2, height: radius * 2))
    }
}

// MARK: - Shape plumbing

/// Lifts a pre-computed `Path` (already in view coordinates) into a
/// SwiftUI `Shape`, so face layers can be styled as views — and can take
/// a real `.glassEffect(in:)` when this face graduates into the app.
private struct OrlojPath: Shape {
    let source: Path
    func path(in rect: CGRect) -> Path { source }
}

/// The faux-glass treatment — `.glassEffect` doesn't render in the
/// widget process, so the look is hand-rolled from parts that rasterise
/// anywhere: a tinted body, a top-lit sheen, a bright top rim, and a
/// drop shadow for lift. ▼ TWEAK the glass recipe here ▼
private struct GlassBand: View {
    let band:   Path
    var tint:   Color  = .white
    var tintOpacity:   Double = 0.10
    var eoFill: Bool   = false

    var body: some View {
        let shape = OrlojPath(source: band)
        let style = FillStyle(eoFill: eoFill)
        ZStack {
            // Body — the tinted glass slab.
            shape.fill(tint.opacity(tintOpacity), style: style)
            // Sheen — light falling from the top.
            shape.fill(LinearGradient(colors: [.white.opacity(0.14),
                                               .white.opacity(0.02)],
                                      startPoint: .top, endPoint: .bottom),
                       style: style)
            // Rim light — bright top edge, fading out below.
            shape.stroke(LinearGradient(colors: [.white.opacity(0.45),
                                                 .white.opacity(0.07)],
                                        startPoint: .top, endPoint: .bottom),
                         lineWidth: 0.8)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1.5)
    }
}

// MARK: - Entry view
// Composes the face back → front: star field (Canvas), the glass dial
// band, the plate/horizon/unequal-hour filigree, the dial scales, the
// glass zodiac band with its ticks, then the hands. Brass hairlines on
// glass slabs — the real instrument's construction.
struct OrlojWidgetView: View {
    var entry: OrlojEntry

    private static let brass    = Color(red: 0.80, green: 0.66, blue: 0.38)
    private static let sunGold  = Color(red: 1.00, green: 0.82, blue: 0.45)
    private static let moonSilk = Color.white

    var body: some View {
        GeometryReader { geo in
            let face = OrlojFace(date: entry.date, origin: entry.origin, size: geo.size)

            ZStack {
                // The sky behind the instrument.
                Canvas { ctx, size in
                    face.drawStars(in: &ctx, size: size)
                }

                // ── Fixed dial band (glass) — the real clock's black
                // outer ring, smoky so the sky reads through it.
                GlassBand(band: face.dialBandPath(),
                          tint: .black, tintOpacity: 0.30, eoFill: true)

                // ── Plate filigree.
                ForEach(Array(face.platePaths().enumerated()), id: \.offset) { _, plate in
                    OrlojPath(source: plate.path)
                        .stroke(Self.brass.opacity(0.85), lineWidth: plate.width)
                }
                OrlojPath(source: face.horizonPath())
                    .stroke(Self.brass.opacity(0.9), lineWidth: 1.3)
                OrlojPath(source: face.unequalHoursPath())
                    .stroke(Self.brass.opacity(0.55), lineWidth: 0.75)

                // ── Dial scales, riding the glass band.
                OrlojPath(source: face.ringCirclePath(declination: OrlojFace.romanDialDec))
                    .stroke(Self.brass.opacity(0.85), lineWidth: 1)
                OrlojPath(source: face.ringTicksPath(declination: OrlojFace.romanDialDec,
                                                     hourOffset: 0,
                                                     tickLength: 8, longEvery: 6))
                    .stroke(Self.brass.opacity(0.85), lineWidth: 1)
                if let hSet = face.bohemianOffset {
                    OrlojPath(source: face.ringCirclePath(declination: OrlojFace.bohemianRingDec))
                        .stroke(Self.brass.opacity(0.55), lineWidth: 0.75)
                    OrlojPath(source: face.ringTicksPath(declination: OrlojFace.bohemianRingDec,
                                                         hourOffset: hSet,
                                                         tickLength: 5, longEvery: 24))
                        .stroke(Self.brass.opacity(0.55), lineWidth: 0.75)
                }

                // ── Rete: the zodiac band (glass, brass-tinted) + ticks.
                GlassBand(band: face.zodiacBandPath(),
                          tint: Self.brass, tintOpacity: 0.16)
                OrlojPath(source: face.zodiacLinePath())
                    .stroke(Self.brass.opacity(0.9), lineWidth: 1)
                OrlojPath(source: face.zodiacTicksPath())
                    .stroke(Self.brass.opacity(0.7), lineWidth: 1)

                // ── Hands.
                if let sun = face.sunPoint {
                    OrlojPath(source: face.handPath(to: sun))
                        .stroke(Self.sunGold, lineWidth: 1.3)
                    GlassBand(band: face.markerPath(at: sun, radius: 6),
                              tint: Self.sunGold, tintOpacity: 0.35)
                    OrlojPath(source: face.markerPath(at: sun, radius: 6))
                        .stroke(Self.sunGold, lineWidth: 1.6)
                }
                if let moon = face.moonPoint {
                    OrlojPath(source: face.handPath(to: moon))
                        .stroke(Self.moonSilk.opacity(0.85), lineWidth: 0.9)
                    GlassBand(band: face.markerPath(at: moon, radius: 4.5),
                              tint: Self.moonSilk, tintOpacity: 0.25)
                    OrlojPath(source: face.markerPath(at: moon, radius: 4.5))
                        .stroke(Self.moonSilk.opacity(0.9), lineWidth: 1.4)
                }
            }
        }
        .containerBackground(for: .widget) {
            EArtist.shared.canvasBackground
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Widget

struct OrlojWidget: Widget {
    let kind: String = "OrlojWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrlojProvider()) { entry in
            OrlojWidgetView(entry: entry)
        }
        .configurationDisplayName("Orloj")
        .description("Your sky, in the geometry of the Prague astronomical clock.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemLarge) {
    OrlojWidget()
} timeline: {
    OrlojEntry(date: .now, origin: nil)
}

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
// same math. So instead of reusing EOrlojGeometry's own simplified
// circle-placement code (which assumes its own unrotated, uncentred
// coordinate frame), everything here is SAMPLED through the real
// `SkyCamera` — the codebase's established pattern (CelestialGridCanvas,
// AlmucantarCurve) — so it's exact for the viewer's actual latitude and
// inherits the camera's real scale/orientation with no separate
// "which way does this rotate" reasoning required.
//
// No per-instance configuration — this is "your sky, right now,
// Orloj-style," large only (there's no room for the full plate + dial +
// rete below systemLarge).
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
// Builds the NorthOUT camera and draws every layer of the astrolabe.
// Z-order mirrors OrlojView: plate → horizon → unequal hours → Roman
// dial → Bohemian ring → zodiac ring → Sun hand → Moon hand — with the
// app's own faint star field underneath as the plate's "sky," and
// constellation figures / planets omitted (the real instrument doesn't
// show them either — only Sun, Moon, and the fixed stars implied by the
// rete's zodiac).
private struct OrlojFace {

    let camera:   SkyCamera
    let date:     Date
    let lst:      Angle
    let latitude: Angle

    private static let brass    = Color(red: 0.80, green: 0.66, blue: 0.38)
    private static let sunGold  = Color(red: 1.00, green: 0.82, blue: 0.45)
    private static let moonSilk = Color.white

    /// Declinations the decorative rings sit at — outside the Tropic of
    /// Cancer plate, Roman dial the outermost. Not solved from a target
    /// radius (a plain circle needs no rotation reasoning either way);
    /// picked to roughly echo the original's 1.10× / 1.04× spacing.
    /// ▼ TWEAK the ring spacing here ▼
    private static let romanDialDec    = AstroConstants.tropicCancer + .degrees(12)
    private static let bohemianRingDec = AstroConstants.tropicCancer + .degrees(6)

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

    private var center: CGPoint { camera.screen(.zero) }

    // MARK: Draw

    @MainActor
    func draw(in ctx: inout GraphicsContext, size: CGSize) {
        drawStars(in: &ctx, size: size)
        drawPlate(in: &ctx)
        drawHorizon(in: &ctx)
        drawUnequalHours(in: &ctx)
        drawDecorativeRing(in: &ctx, declination: Self.romanDialDec,
                           hourOffset: 0, tickLength: 8, longEvery: 6,
                           opacity: 0.85, lineWidth: 1)
        if let hSet = Self.sunsetHourAngle(declination: sunDec, latitude: latitude) {
            drawDecorativeRing(in: &ctx, declination: Self.bohemianRingDec,
                               hourOffset: hSet, tickLength: 5, longEvery: 24,
                               opacity: 0.55, lineWidth: 0.75)
        }
        drawZodiac(in: &ctx)
        drawSunHand(in: &ctx)
        drawMoonHand(in: &ctx)
    }

    /// Faint naked-eye field — kept sparse (mag ≤ 3.6) so the brass
    /// geometry stays the thing you actually read.
    private func drawStars(in ctx: inout GraphicsContext, size: CGSize) {
        for star in StarDatabase.shared.workableStars where star.magnitude <= 3.6 {
            guard let sc = camera.screen(equatorial: star.equatorialVector),
                  sc.x > -4, sc.x < size.width + 4,
                  sc.y > -4, sc.y < size.height + 4 else { continue }
            let r = max(0.6, 1.8 - 0.35 * star.magnitude)
            ctx.fill(orlojDot(sc, radius: r), with: .color(.white.opacity(0.5)))
        }
    }

    /// The fixed plate: Tropic of Capricorn (inner), equator, Tropic of
    /// Cancer (outer) — the SAME declination-circle formula the app's
    /// NorthOUT mode already uses, sampled through this camera.
    private func drawPlate(in ctx: inout GraphicsContext) {
        for (dec, width) in [(AstroConstants.tropicCapricorn, 1.0),
                             (Angle.zero,                     1.6),
                             (AstroConstants.tropicCancer,    1.0)] {
            ctx.stroke(sampledParallel(declination: dec),
                      with: .color(Self.brass.opacity(0.85)), lineWidth: width)
        }
    }

    /// The horizon — altitude = 0 around the OBSERVER's zenith (not the
    /// pole), clipped to the Tropic of Cancer like the real tympan.
    private func drawHorizon(in ctx: inout GraphicsContext) {
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
        ctx.stroke(path, with: .color(Self.brass.opacity(0.9)), lineWidth: 1.3)
    }

    /// Unequal (planetary) hours: the day arc between sunrise and sunset,
    /// split into 12, one curved line per hour fitted through its point
    /// on all three plate circles.
    private func drawUnequalHours(in ctx: inout GraphicsContext) {
        let decs: [Angle] = [AstroConstants.tropicCancer, .zero, AstroConstants.tropicCapricorn]
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
            var path = Path()
            if pts.count == 3, let circle = Self.circle(through: pts[0], pts[1], pts[2]) {
                path = Self.arcPolyline(centre: circle.centre, radius: circle.radius,
                                       from: pts[0], through: pts[1], to: pts[2])
            } else {
                path.move(to: pts.first!)
                path.addLine(to: pts.last!)
            }
            ctx.stroke(path, with: .color(Self.brass.opacity(0.55)), lineWidth: 0.75)
        }
    }

    /// A generic hour-ticked ring at a fixed declination — the Roman
    /// dial (offset 0) and the Old-Bohemian ring (offset by sunset hour
    /// angle) are the same shape, just different phase and tick rhythm.
    /// The outline is a plain circle (rotation-agnostic — a circle has
    /// no "direction"); only the ticks need the real hour-angle
    /// projection, since THEY carry meaning (they must land where the
    /// Sun hand will actually cross at that hour).
    private func drawDecorativeRing(in ctx: inout GraphicsContext,
                                    declination dec: Angle,
                                    hourOffset: Double,
                                    tickLength: CGFloat,
                                    longEvery: Int,
                                    opacity: Double,
                                    lineWidth: CGFloat) {
        ctx.stroke(orlojCircle(center, radiusForDeclination(dec)),
                  with: .color(Self.brass.opacity(opacity)), lineWidth: lineWidth)
        for h in 0..<24 {
            let H = hourOffset + Double(h) / 24 * 2 * .pi
            guard let p = ringPoint(hourAngle: H, declination: dec) else { continue }
            let long = (h % longEvery == 0) ? tickLength * 1.6 : tickLength
            ctx.stroke(tick(at: p, toward: center, length: long),
                      with: .color(Self.brass.opacity(opacity)), lineWidth: lineWidth)
        }
    }

    /// The rete's zodiac ring — an off-centre circle carrying the
    /// ecliptic, ROTATING with sidereal time (unlike the plate above).
    /// The Sun always sits on it by construction.
    private func drawZodiac(in ctx: inout GraphicsContext) {
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
        ctx.stroke(path, with: .color(Self.brass.opacity(0.9)), lineWidth: 1.4)

        // 12 sign-boundary ticks, pointing toward the pole centre — a
        // close stand-in for the real ring's own off-centre pivot,
        // indistinguishable at this size.
        for i in 0..<12 {
            guard let p = camera.screen(equatorial: .eclipticPoint(lambda: .degrees(Double(i) * 30)))
            else { continue }
            ctx.stroke(tick(at: p, toward: center, length: 8),
                      with: .color(Self.brass.opacity(0.7)), lineWidth: 1)
        }
    }

    private func drawSunHand(in ctx: inout GraphicsContext) {
        guard let p = camera.screen(equatorial: .eclipticPoint(lambda: sunLambda)) else { return }
        var hand = Path()
        hand.move(to: center)
        hand.addLine(to: p)
        ctx.stroke(hand, with: .color(Self.sunGold), lineWidth: 1.3)
        ctx.stroke(orlojCircle(p, 6), with: .color(Self.sunGold), lineWidth: 1.6)
        ctx.fill(orlojCircle(p, 6), with: .color(Self.sunGold.opacity(0.3)))
    }

    private func drawMoonHand(in ctx: inout GraphicsContext) {
        let (vec, _, _) = EMoonPosition.vector(for: date, siderealOffset: camera.sidereal)
        guard let p = camera.screen(rotatedEquatorial: vec) else { return }
        var hand = Path()
        hand.move(to: center)
        hand.addLine(to: p)
        ctx.stroke(hand, with: .color(Self.moonSilk.opacity(0.85)), lineWidth: 0.9)
        ctx.stroke(orlojCircle(p, 4.5), with: .color(Self.moonSilk.opacity(0.9)), lineWidth: 1.4)
    }

    // MARK: Sun helpers

    private var sunLambda: Angle { ESunPosition.eclipticLongitude(for: date) }
    private var sunDec:    Angle { ESunPosition.equatorialCoords(lambda: sunLambda).dec }

    // MARK: Sampling helpers

    /// A full constant-declination circle, RA swept 0…2π — the plate's
    /// tropic/equator circles and (reused for its outline) the decorative
    /// rings.
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
    /// consistent with every other hour-angle element by construction:
    /// no separate "which way does H increase on screen" derivation
    /// needed, because it's never assumed — only ever projected.
    private func ringPoint(hourAngle H: Double, declination dec: Angle) -> CGPoint? {
        let q = EPrecession.equatorialVector(ra: .radians(lst.radians - H), dec: dec)
        return camera.screen(equatorial: q)
    }

    /// Closed-form declination-circle radius — valid ONLY as a
    /// rotation-agnostic distance-from-centre (clipping thresholds,
    /// plain circle outlines), never for placing a specific point
    /// (that always goes through the real per-point projection above).
    /// ρ = 2·tan(45°+δ/2) — the 2 is EProjection's convention (horizon
    /// at ρ=2 in NorthIN); dropping it once made every ring render at
    /// double size while these outlines sat at half their own ticks.
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

    /// Inward tick from `point` toward `center`, `length` points long.
    private func tick(at point: CGPoint, toward center: CGPoint, length: CGFloat) -> Path {
        let dx = center.x - point.x, dy = center.y - point.y
        let len = max(hypot(dx, dy), 0.0001)
        let inner = CGPoint(x: point.x + dx / len * length, y: point.y + dy / len * length)
        var p = Path()
        p.move(to: point)
        p.addLine(to: inner)
        return p
    }

    private func orlojCircle(_ centre: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                              width: radius * 2, height: radius * 2))
    }

    private func orlojDot(_ centre: CGPoint, radius: CGFloat) -> Path {
        orlojCircle(centre, radius)
    }
}

// MARK: - Entry view

struct OrlojWidgetView: View {
    var entry: OrlojEntry

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let face = OrlojFace(date: entry.date, origin: entry.origin, size: size)
                face.draw(in: &ctx, size: size)
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

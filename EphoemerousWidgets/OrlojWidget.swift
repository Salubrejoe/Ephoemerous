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

    let camera:    SkyCamera
    let date:      Date
    let lst:       Angle
    let latitude:  Angle
    let longitude: Angle

    /// Declination the Roman dial sits at — outside the Tropic of
    /// Cancer plate. (The Old-Bohemian ring is retired — conductor's
    /// call — so the crown carries one scale.) ▼ TWEAK ring spacing ▼
    static let romanDialDec = AstroConstants.tropicCancer + .degrees(12)

    @MainActor
    init(date: Date, origin: (latDeg: Double, lonDeg: Double)?, size: CGSize) {
        self.date = date
        // Prague fallback before the app has ever backgrounded — apt for
        // the one widget that's explicitly styled after this city's clock.
        let lat = Angle.degrees(origin?.latDeg ?? 50.09)
        let lon = Angle.degrees(origin?.lonDeg ?? 14.42)
        latitude  = lat
        longitude = lon
        lst = EPrecession.lst(for: date, longitude: lon)

        let viewpoint = EProjection.Viewpoint(
            originVector: Angle.spherePoint(latitude: lat, longitude: lon),
            planeVector:  Angle.spherePoint(latitude: .radians(-lat.radians),
                                            longitude: lon + .radians(.pi)),
            morph: 1)   // pure NorthOUT — this IS the astrolabe's projection

        // ▼ TWEAK the dial size here — fit the Roman dial ring within
        // ~42% of the shorter side (numerals need breathing room past
        // it). Solved directly (radius is linear in scale). NOTE the
        // factor 2: EProjection's stereographic puts a declination
        // circle at ρ = 2·tan(45°+δ/2) projection units — the same 2 as
        // northOutDefaultScale's derivation. ▼
        let targetOuterRadius = min(size.width, size.height) * 0.52
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
        for star in StarDatabase.shared.workableStars where star.magnitude <= 4.6 {
            guard let sc = camera.screen(equatorial: star.equatorialVector),
                  sc.x > -4, sc.x < size.width + 4,
                  sc.y > -4, sc.y < size.height + 4 else { continue }
            let r = max(0.6, 1.8 - 0.35 * star.magnitude)
            ctx.fill(circle(sc, r), with: .color(.white.opacity(0.4)))
        }
    }

    // MARK: Plate (fixed)

    /// Tropic of Capricorn (inner), equator, Tropic of Cancer (outer) —
    /// each with its stroke weight, the equator emphasised.
    @MainActor
    func platePaths() -> [(path: Path, width: CGFloat)] {
        [(sampledParallel(declination: AstroConstants.tropicCapricorn), 0.5),
         (sampledParallel(declination: .zero),                          0.9),
         (sampledParallel(declination: AstroConstants.tropicCancer),    0.5)]
    }

    /// A constant-altitude circle around the OBSERVER's zenith (not the
    /// pole), clipped to the Tropic of Cancer like the real tympan.
    /// altitude 0 = the horizon; −18° = the astronomical-twilight line
    /// that bounds the AVRORA / CREPVSCVLVM bands on the original.
    @MainActor
    func almucantarPath(altitude: Angle) -> Path {
        let clip = radiusForDeclination(AstroConstants.tropicCancer) * 1.26
        var path = Path()
        var started = false
        for i in 0...160 {
            let t = Double(i) / 160
            let q = camera.viewpoint.skyPoint(altitude: altitude, at: t)
            if let sc = camera.screen(rotatedEquatorial: q),
               hypot(sc.x - center.x, sc.y - center.y) <= clip {
                if started { path.addLine(to: sc) } else { path.move(to: sc); started = true }
            } else {
                started = false
            }
        }
        return path
    }

    @MainActor
    func horizonPath() -> Path { almucantarPath(altitude: .zero) }

    /// The tympan's Latin region labels, exactly the original's wording:
    /// ORTVS (rising) on the day side of the east horizon, AVRORA in the
    /// east twilight band, OCCASVS / CREPVSCVLVM their west mirrors, NOX
    /// in the northern dark. Positions are PROJECTED from (azimuth,
    /// altitude) — east and west land where they physically are, no
    /// left/right assumption.
    ///
    /// Vended PER CHARACTER so the words genuinely FOLLOW their band's
    /// curve (the app's cartography-rim treatment): each glyph sits at
    /// its own azimuth along the constant-altitude circle, rotated to
    /// the local tangent. Reading direction is decided once per word
    /// from the mid tangent — flipped words reverse their marching
    /// direction and rotate each glyph by π, so text always reads
    /// left-to-right and upright.
    @MainActor
    func tympanLabelChars() -> [(id: String, char: String, position: CGPoint, rotation: Angle)] {
        // ▼ TWEAK the label anchors here (azimuth°, altitude°) ▼
        let specs: [(String, Double, Double)] = [
            ("ORTVS",        90,   5),
            ("AVRORA",       90,  -9),
            ("OCCASVS",     270,   5),
            ("CREPVSCVLVM", 270,  -9),
            ("NOX",           0, -24),
        ]
        // ▼ TWEAK per-character arc spacing (pt) ▼
        let spacing: CGFloat = 8
        let clip = radiusForDeclination(AstroConstants.tropicCancer) * 0.97

        var out: [(String, String, CGPoint, Angle)] = []
        for (text, azDeg, altDeg) in specs {
            func point(_ az: Double) -> CGPoint? {
                let q = camera.viewpoint.skyPoint(azimuth: az * .pi / 180,
                                                  altitude: altDeg * .pi / 180)
                return camera.screen(rotatedEquatorial: q)
            }
            guard let anchor = point(azDeg),
                  hypot(anchor.x - center.x, anchor.y - center.y) <= clip,
                  let step = point(azDeg + 1),
                  let tb   = point(azDeg - 2),
                  let ta   = point(azDeg + 2) else { continue }

            let pxPerDeg = max(hypot(step.x - anchor.x, step.y - anchor.y), 0.01)
            let dAz      = Double(spacing / pxPerDeg)
            let midA     = atan2(Double(ta.y - tb.y), Double(ta.x - tb.x))
            let flip     = midA > .pi / 2 || midA < -.pi / 2

            let chars = Array(text)
            for (k, ch) in chars.enumerated() {
                let centred = Double(k) - Double(chars.count - 1) / 2
                let az = azDeg + (flip ? -centred : centred) * dAz
                guard let cp = point(az),
                      let cb = point(az - 2),
                      let ca = point(az + 2) else { continue }
                var rot = atan2(Double(ca.y - cb.y), Double(ca.x - cb.x))
                if flip { rot += .pi }
                out.append(("\(text)-\(k)", String(ch), cp, .radians(rot)))
            }
        }
        return out
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

    /// The crown: the outer dial as a GLASS BAND whose outer edge is the
    /// app's SIGNATURE SCALLOPED SQUIRCLE — the same corner/bulge pair
    /// as the horizon rim (EArtist.horizonBump*, the DateCrown language).
    /// Inner edge stays a true circle (the dial side). Even-odd.
    /// ▼ TWEAK the band edges here ▼
    @MainActor
    func dialBandPath() -> Path {
        let roman  = radiusForDeclination(Self.romanDialDec)
        let outerR = roman + 19
        let rect   = CGRect(x: center.x - outerR, y: center.y - outerR,
                            width: outerR * 2, height: outerR * 2)
        var path = Squircle(corners: EArtist.shared.horizonBumpCorners,
                            bulge:   EArtist.shared.horizonBumpBulge).path(in: rect)
        path.addPath(circle(center, roman + 3))
        return path
    }

    // MARK: Favourites & planets (the app's own marks on the plate)

    /// Remembered constellations, traced SOLID over the tympan — the
    /// postcard widget's hero treatment, here for every favourite.
    @MainActor
    func favouriteConstellationsPath() -> Path {
        let favs = Set(FavouritesStore().constellations())
        guard !favs.isEmpty else { return Path() }
        let clip = radiusForDeclination(Self.romanDialDec) + 3
        var merged = Path()
        for (cons, segs) in ConstellationLines.shared.segments where favs.contains(cons) {
            for seg in segs {
                guard let a = camera.screen(equatorial: seg.a.equatorialVector),
                      let b = camera.screen(equatorial: seg.b.equatorialVector),
                      hypot(a.x - b.x, a.y - b.y) < clip,
                      hypot(a.x - center.x, a.y - center.y) < clip ||
                      hypot(b.x - center.x, b.y - center.y) < clip else { continue }
                merged.move(to: a)
                merged.addLine(to: b)
            }
        }
        return merged
    }

    /// Remembered stars as the app's tier-0 mark: the tiny SPECTRAL
    /// PENTAGON squircle (FavouriteHeart's below-badge-tier form).
    @MainActor
    func favouriteStarMarks() -> [(id: String, position: CGPoint, top: Color, bottom: Color)] {
        let clip = radiusForDeclination(Self.romanDialDec) + 3
        var out: [(String, CGPoint, Color, Color)] = []
        for star in FavouritesStore().stars(key: FavouritesStore.Key.favouriteStars) {
            guard let sc = camera.screen(equatorial: star.equatorialVector),
                  hypot(sc.x - center.x, sc.y - center.y) < clip else { continue }
            let g = star.spectralClass.badgeGradient
            out.append((star.name, sc, g.top, g.bottom))
        }
        return out
    }

    /// The seven planets in their canonical tints — riding the ecliptic
    /// through the rete, like the wanderers they are.
    @MainActor
    func planetMarks() -> [(id: String, position: CGPoint, top: Color, bottom: Color)] {
        var out: [(String, CGPoint, Color, Color)] = []
        for (planet, vec, _, _) in EPlanetPosition.allVectors(for: date,
                                                              siderealOffset: camera.sidereal) {
            guard let sc = camera.screen(rotatedEquatorial: vec) else { continue }
            let g = EArtist.shared.planetGradient(planet)
            out.append((planet.name, sc, g.top, g.bottom))
        }
        return out
    }

    /// Phase that makes the Roman dial read CIVIL time — the device
    /// timezone, DST-aware. The Sun hand's direction is apparent solar
    /// time; at civil hour h the sun sits at hour angle
    /// (h + Δ − 12)·15°, where Δ = longitude/15h − tz offset. Anchoring
    /// tick h there means hand-against-numeral reads the wall clock —
    /// exactly what the real Orloj's Roman ring does for CET. (The
    /// ±16 min equation-of-time wobble is accepted: ours is the REAL
    /// apparent sun; the original's clockwork hand is a mean sun.)
    var civilDialPhase: Double {
        let tzHours  = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600
        let lonHours = longitude.degrees / 15
        return (lonHours - tzHours - 12) * (2 * .pi / 24)
    }

    /// Roman numerals for the 24 CIVIL hours, positioned just outside
    /// the dial circle and rotated feet-to-centre, like the original.
    @MainActor
    func dialNumerals(radiusPadding: CGFloat = 11)
        -> [(id: Int, text: String, position: CGPoint, rotation: Angle)] {
        let r = radiusForDeclination(Self.romanDialDec) + radiusPadding
        var out: [(Int, String, CGPoint, Angle)] = []
        for h in 0..<24 {
            let H = civilDialPhase + Double(h) / 24 * 2 * .pi
            guard let onRing = ringPoint(hourAngle: H, declination: Self.romanDialDec)
            else { continue }
            let dx  = onRing.x - center.x, dy = onRing.y - center.y
            let len = max(hypot(dx, dy), 0.0001)
            let p   = CGPoint(x: center.x + dx / len * r,
                              y: center.y + dy / len * r)
            let rot = Angle.radians(atan2(Double(dy), Double(dx)) + .pi / 2)
            out.append((h, Self.romanTexts[h % 12], p, rot))
        }
        return out
    }

    private static let romanTexts = ["XII", "I", "II", "III", "IV", "V",
                                     "VI", "VII", "VIII", "IX", "X", "XI"]

    // MARK: Rete (rotates with the sky)

    /// Zodiac band width — glyphs (11pt) sit between the edge lines.
    /// ▼ TWEAK ▼
    static let zodiacBandWidth: CGFloat = 16

    /// The projected ecliptic as an exact circle — the projected image
    /// of the ecliptic IS a true circle, so three points pin it. Every
    /// rete element (band, edges, ticks, glyph orientation) derives
    /// from this one centre + radius.
    @MainActor
    func eclipticCircle() -> (centre: CGPoint, radius: CGFloat)? {
        guard let a = camera.screen(equatorial: .eclipticPoint(lambda: .degrees(0))),
              let b = camera.screen(equatorial: .eclipticPoint(lambda: .degrees(120))),
              let c = camera.screen(equatorial: .eclipticPoint(lambda: .degrees(240)))
        else { return nil }
        return Self.circle(through: a, b, c)
    }

    /// The zodiac as a GLASS BAND — a true annulus about the projected
    /// ecliptic circle, the ecliptic its centreline. Even-odd.
    @MainActor
    func zodiacBandPath() -> Path {
        guard let ring = eclipticCircle() else { return Path() }
        var path = circle(ring.centre, ring.radius + Self.zodiacBandWidth / 2)
        path.addPath(circle(ring.centre, ring.radius - Self.zodiacBandWidth / 2))
        return path
    }

    /// The band's rim lines — outer and inner edge circles, exactly the
    /// annulus's own boundaries.
    @MainActor
    func zodiacEdgePaths() -> (outer: Path, inner: Path)? {
        guard let ring = eclipticCircle() else { return nil }
        return (circle(ring.centre, ring.radius + Self.zodiacBandWidth / 2),
                circle(ring.centre, ring.radius - Self.zodiacBandWidth / 2))
    }

    /// 12 sign-boundary dividers, SPANNING the band rim to rim like the
    /// original's compartment walls.
    @MainActor
    func zodiacTicksPath() -> Path {
        guard let ring = eclipticCircle() else { return Path() }
        var merged = Path()
        for i in 0..<12 {
            guard let p = camera.screen(
                equatorial: .eclipticPoint(lambda: .degrees(Double(i) * 30)))
            else { continue }
            let dx  = p.x - ring.centre.x, dy = p.y - ring.centre.y
            let len = max(hypot(dx, dy), 0.0001)
            let ux  = dx / len, uy = dy / len
            let rIn  = ring.radius - Self.zodiacBandWidth / 2
            let rOut = ring.radius + Self.zodiacBandWidth / 2
            merged.move(to:    CGPoint(x: ring.centre.x + ux * rIn,
                                       y: ring.centre.y + uy * rIn))
            merged.addLine(to: CGPoint(x: ring.centre.x + ux * rOut,
                                       y: ring.centre.y + uy * rOut))
        }
        return merged
    }

    /// The 12 zodiac glyphs (EZodiacSign — Aries at λ 0°) at their sign
    /// midpoints on the band's CENTRELINE — between the rim lines — feet
    /// toward the ring's own centre, the original's orientation.
    @MainActor
    func zodiacGlyphs() -> [(id: Int, symbol: String, position: CGPoint, rotation: Angle)] {
        guard let ring = eclipticCircle() else { return [] }
        var out: [(Int, String, CGPoint, Angle)] = []
        for sign in EZodiacSign.zodiac {
            let mid = Angle.degrees(Double(sign.index - 1) * 30 + 15)
            guard let p = camera.screen(equatorial: .eclipticPoint(lambda: mid))
            else { continue }
            let rot = Angle.radians(atan2(Double(p.y - ring.centre.y),
                                          Double(p.x - ring.centre.x)) + .pi / 2)
            out.append((sign.index, sign.symbol, p, rot))
        }
        return out
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

    // MARK: Sun helpers

    private var sunLambda: Angle { ESunPosition.eclipticLongitude(for: date) }

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
        camera.scale * 0.81 * CGFloat(2 * tan(.pi / 4 + dec.radians / 2))
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
            // Body — a vertical GRADIENT slab, the badge-orb treatment
            // (bright above, deep below) instead of a flat tint.
            shape.fill(LinearGradient(colors: [tint.opacity(tintOpacity * 1.4),
                                               tint.opacity(tintOpacity * 0.6)],
                                      startPoint: .top, endPoint: .bottom),
                       style: style)
            // Sheen — light falling from the top.
            shape.fill(LinearGradient(colors: [.white.opacity(0.14),
                                               .white.opacity(0.02)],
                                      startPoint: .top, endPoint: .bottom),
                       style: style)
            // Casing — the dark border every Ephoemerous badge wears
            // (poiTextBorderWidth, canvas-navy so it never goes light).
            shape.stroke(EArtist.shared.canvasBackground.opacity(0.9),
                         lineWidth: EArtist.shared.poiTextBorderWidth)
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
    /// The SKY-side ink — horizon, twilight, unequal hours, ecliptic:
    /// everything that belongs to the heavens reads silver, while the
    /// instrument's own concentric metalwork stays gold.
    private static let silver   = Color(red: 0.78, green: 0.82, blue: 0.88)

    /// The numerals' voice — the same serif-semibold the POI labels use,
    /// as a concrete UIFont for OutlinedText's CoreText layout.
    private static let numeralFont: UIFont = {
        var desc = UIFont.systemFont(ofSize: 9, weight: .semibold).fontDescriptor
        desc = desc.withDesign(.serif) ?? desc
        return UIFont(descriptor: desc, size: 9)
    }()

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
                // Sky-side lines read SILVER (horizon, twilight, unequal
                // hours) — the heavens against the instrument's gold.
                OrlojPath(source: face.horizonPath())
//                    .stroke(Self.silver.opacity(0.85), lineWidth: 0.5)
                    .stroke(
                        Self.silver.opacity(0.55),
                        style: .init(
                            lineWidth: 0.8,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [10,10],
                            dashPhase: 20
                        )
                    )
                // Astronomical-twilight line — the AVRORA/CREPVSCVLVM
                // bands' inner boundary, the night's edge.
                OrlojPath(source: face.almucantarPath(altitude: .degrees(-18)))
                    .stroke(Self.silver.opacity(0.4), lineWidth: 0.5)
                OrlojPath(source: face.unequalHoursPath())
                    .stroke(Self.silver.opacity(0.5), lineWidth: 0.5)

                // Remembered constellations — traced solid, the postcard
                // widget's hero treatment for every favourite.
                OrlojPath(source: face.favouriteConstellationsPath())
                    .stroke(Self.silver.opacity(0.85),
                            style: .init(lineWidth: 1, lineCap: .round, lineJoin: .round))

                // Tympan region labels — the original's Latin, laid out
                // character by character ALONG their bands' curves, with
                // the app's dark casing so they hold up at a squint.
                ForEach(face.tympanLabelChars(), id: \.id) { glyph in
                    Text(glyph.char)
                        .font(.system(size: 6.5, weight: .medium, design: .serif))
                        .foregroundStyle(Self.silver.opacity(0.8))
                        .shadow(color: EArtist.shared.canvasBackground.opacity(0.9),
                                radius: 1)
                        .rotationEffect(glyph.rotation)
                        .position(glyph.position)
                }

                // ── The crown carries NUMERALS ALONE, in the app's label
                // voice: OutlinedText — serif brass with the real dark
                // casing, crisp at any zoom, squint-proof. Phased to
                // CIVIL time (device timezone, DST-aware) — hand against
                // numeral reads the wall clock.
                ForEach(face.dialNumerals(), id: \.id) { numeral in
                    OutlinedText(text:      numeral.text,
                                 fill:      Self.brass,
                                 stroke:    EArtist.shared.canvasBackground,
                                 lineWidth: 1.2,
                                 font:      Self.numeralFont)
                        .rotationEffect(numeral.rotation)
                        .position(numeral.position)
                }
                // ── Rete: the zodiac band — smoky dark glass like the
                // original's black ring, its RIM LINES traced silver
                // (outer leading, inner echoed), sign dividers spanning
                // rim to rim, and GOLD glyphs between the rims with a
                // hard dark shadow (Prague's gold-on-black, boom).
                GlassBand(band: face.zodiacBandPath(),
                          tint: .black, tintOpacity: 0.35, eoFill: true)
                if let edges = face.zodiacEdgePaths() {
                    OrlojPath(source: edges.outer)
                        .stroke(Self.silver.opacity(0.85), lineWidth: 1)
                    OrlojPath(source: edges.inner)
                        .stroke(Self.silver.opacity(0.65), lineWidth: 0.8)
                }
                OrlojPath(source: face.zodiacTicksPath())
                    .stroke(Self.silver.opacity(0.6), lineWidth: 0.8)
                ForEach(face.zodiacGlyphs(), id: \.id) { glyph in
                    Text(glyph.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Self.silver)
                        .shadow(color: .black.opacity(0.9), radius: 1, y: 0.5)
                        .rotationEffect(glyph.rotation)
                        .position(glyph.position)
                }

                // ── The wanderers and the remembered — the app's OWN
                // marks, badge grammar and all: spectral PENTAGON
                // squircles for favourite stars, canonical-tint rounded
                // squircles for the seven planets, each with the badge's
                // gradient fill, dark casing, and soft glow.
                ForEach(face.favouriteStarMarks(), id: \.id) { mark in
                    Squircle(corners: 5, bulge: EArtist.shared.poiBadgeBulge)
                        .fill(LinearGradient(colors: [mark.top, mark.bottom],
                                             startPoint: .bottom, endPoint: .top))
                        .overlay(
                            Squircle(corners: 5, bulge: EArtist.shared.poiBadgeBulge)
                                .stroke(EArtist.shared.canvasBackground.opacity(0.9),
                                        lineWidth: 1.1)
                        )
                        .frame(width: 9, height: 9)
                        .shadow(color: mark.top.opacity(0.5), radius: 1.5)
                        .position(mark.position)
                }
                ForEach(face.planetMarks(), id: \.id) { mark in
                    Squircle(corners: 4, bulge: 2.0)
                        .fill(LinearGradient(colors: [mark.top, mark.bottom],
                                             startPoint: .bottom, endPoint: .top))
                        .overlay(
                            Squircle(corners: 4, bulge: 2.0)
                                .stroke(EArtist.shared.canvasBackground.opacity(0.9),
                                        lineWidth: 1)
                        )
                        .frame(width: 7, height: 7)
                        .shadow(color: mark.top.opacity(0.45), radius: 1.2)
                        .position(mark.position)
                }

                // ── Hands — tipped with the app's OWN Sun and Moon
                // badges (POILabelView, same species as everywhere).
                if let sun = face.sunPoint {
                    OrlojPath(source: face.handPath(to: sun))
                        .stroke(Self.sunGold, lineWidth: 1.3)
                        .shadow(color: Self.sunGold.opacity(0.5), radius: 2)
                    POILabelView(category:   .sun,
                                 text:       "",
                                 labelStyle: .star,
                                 nameReveal: 0)
                        .position(sun)
                }
                if let moon = face.moonPoint {
                    OrlojPath(source: face.handPath(to: moon))
                        .stroke(Self.moonSilk.opacity(0.85), lineWidth: 0.9)
                    POILabelView(category:   .moon,
                                 text:       "",
                                 labelStyle: .planetoids,
                                 nameReveal: 0)
                        .position(moon)
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

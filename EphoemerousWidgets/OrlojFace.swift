import SwiftUI
import LoreKit
import simd

// MARK: - OrlojFace
// The Prague astronomical clock, superimposed on the app's REAL NorthOUT
// projection — not a lookalike drawing, the SAME projection (see the
// header note in OrlojWidget.swift). Builds the NorthOUT camera and vends
// every layer of the astrolabe as a `Path` in view coordinates. Pure
// geometry — no drawing, no style; `OrlojFaceLayers` decides what's
// glass, what's filigree.
//
// SHARED between the iOS widget (OrlojWidget) and the watch app
// (OrlojWatchView) — deliberately free of WidgetKit so it compiles on
// watchOS. Keep it that way.
struct OrlojFace {

    let camera:    SkyCamera
    let date:      Date
    let lst:       Angle
    let latitude:  Angle
    let longitude: Angle
    /// UI scale — 1 on the large tile, ~0.46 on the small one (and the
    /// watch). The PROJECTION scales itself (everything derives from
    /// `size`); this factor shrinks the fixed-point dressing — fonts,
    /// band widths, marks — so the whole instrument miniaturises
    /// coherently.
    let ui:        CGFloat

    /// Declination MAGNITUDE the Roman dial sits at — outside the outer
    /// tropic plate. (The Old-Bohemian ring is retired — conductor's
    /// call — so the crown carries one scale.) ▼ TWEAK ring spacing ▼
    static let romanDialBase = AstroConstants.tropicCancer + .degrees(12)

    /// The face's naked-eye star field, computed ONCE per process.
    /// `workableStars` rebuilds ~9k structs per ACCESS — fine for a
    /// widget's single render per timeline entry, lethal on the watch
    /// where the Digital Crown re-renders the face every tick.
    private static let starField: [Star] =
        StarDatabase.shared.workableStars.filter { $0.magnitude <= 4.6 }

    /// +1 north of the equator, −1 south. The projection flings out the
    /// observer's HIDDEN pole (see `Projection.project(_:viewpoint:)`),
    /// so every hardcoded northern declination mirrors below the equator
    /// — the tympan builds around the other pole.
    private var hemi: Double { latitude.radians >= 0 ? 1 : -1 }

    /// The dial's actual declination — `romanDialBase`, mirrored for the
    /// southern hemisphere.
    var romanDialDec: Angle { .radians(hemi * Self.romanDialBase.radians) }

    /// The OUTER tropic under the current projection — Cancer in the
    /// north, Capricorn in the south (the tympan's traditional clip).
    private var outerTropic: Angle {
        .radians(hemi * AstroConstants.tropicCancer.radians)
    }

    @MainActor
    init(date: Date, origin: (latDeg: Double, lonDeg: Double)?, size: CGSize) {
        self.date = date
        // Prague fallback before the app has ever backgrounded — apt for
        // the one face that's explicitly styled after this city's clock.
        let lat = Angle.degrees(origin?.latDeg ?? 50.09)
        let lon = Angle.degrees(origin?.lonDeg ?? 14.42)
        latitude  = lat
        longitude = lon
        lst = Precession.lst(for: date, longitude: lon)
        ui  = min(1, min(size.width, size.height) / 340)   // systemLarge ≈ 1

        let viewpoint = Projection.Viewpoint(
            originVector: Angle.spherePoint(latitude: lat, longitude: lon),
            planeVector:  Angle.spherePoint(latitude: .radians(-lat.radians),
                                            longitude: lon + .radians(.pi)),
            morph: 1)   // pure NorthOUT — this IS the astrolabe's projection

        // ▼ TWEAK the dial size here — fit the Roman dial ring within
        // ~42% of the shorter side (numerals need breathing room past
        // it). Solved directly (radius is linear in scale). NOTE the
        // factor 2: Projection's stereographic puts a declination
        // circle at ρ = 2·tan(45°+δ/2) projection units — the same 2 as
        // northOutDefaultScale's derivation. ▼
        let targetOuterRadius = min(size.width, size.height) * 0.52
        // The magnitude is hemisphere-invariant: the dial dec mirrors AND
        // the projection mirrors, so the radius comes out identical.
        let romanRho = 2 * tan(.pi / 4 + Self.romanDialBase.radians / 2)
        let scale = targetOuterRadius / CGFloat(romanRho)

        // The face must stand STILL — meridian vertical, noon at top,
        // the sky rotating over it (dial fixed, rete turns — the real
        // mechanism). At morph 1 the screen basis is east-pinned (see
        // Projection) but still time-dependent through `sidereal`, so:
        // project a probe at H = 0 (upper meridian, RA = LST) with an
        // unrotated camera, measure where it landed, and set the camera
        // rotation that carries it straight UP.
        //
        // `sidereal` is −GMST, NOT −LST: the anchors (`originVector`,
        // `skyPoint`'s zenith) are geographic globe vectors, so longitude
        // lives in the anchor and the sky spins over it by GMST alone —
        // same frame as the app (see AppState.localSiderealOffset).
        // −LST double-counted longitude and spun the tympan (horizon,
        // twilight bands, Latin labels) by `lon` against the rete/ring.
        let sidereal = -Precession.gmstSiderealOffset(for: date)
        let unrotated = SkyCamera(scale: scale, offset: .zero, size: size,
                                 viewpoint: viewpoint, sidereal: sidereal)
        var rotation = Angle.zero
        let c = unrotated.screen(.zero)
        if let probe = unrotated.screen(
            equatorial: Precession.equatorialVector(ra: lst, dec: .zero)) {
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
    func drawStars(in ctx: inout GraphicsContext, size: CGSize, gain: Double = 1) {
        // The small tile takes a sparser field (mag 3.8) — the same dot
        // count at a quarter the area would read as fog, not sky.
        let magLimit = ui < 0.7 ? 3.8 : 4.6
        for star in Self.starField where star.magnitude <= magLimit {
            guard let sc = camera.screen(equatorial: star.equatorialVector),
                  sc.x > -4, sc.x < size.width + 4,
                  sc.y > -4, sc.y < size.height + 4 else { continue }
            let r = max(0.5, (1.8 - 0.35 * star.magnitude) * ui)
            ctx.fill(circle(sc, r), with: .color(.white.opacity(min(1, 0.4 * gain))))
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
        let clip = radiusForDeclination(outerTropic) * 1.26
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

    // MARK: Tympan fields (fixed)
    // Day, twilight and night as MATERIAL, the Prague read — you see
    // which field the Sun is in, and the horizon is the EDGE between
    // fields, not a hairline you hunt for. Geometry rests on one fact:
    // constant-altitude circles project to TRUE circles under the
    // stereographic, so three sample points pin each one exactly
    // (`eclipticCircle`'s trick). Near the poles a circle can fail to
    // fit — the vends go nil/empty and the plate simply wears fewer
    // veils that day.

    /// Exact centre + radius of one almucantar.
    @MainActor
    private func almucantarCircle(altitude: Angle) -> (centre: CGPoint, radius: CGFloat)? {
        func point(_ t: Double) -> CGPoint? {
            camera.screen(rotatedEquatorial:
                camera.viewpoint.skyPoint(altitude: altitude, at: t))
        }
        guard let a = point(0), let b = point(1.0 / 3), let c = point(2.0 / 3)
        else { return nil }
        return Self.circle(through: a, b, c)
    }

    /// The plate's face — everything inside the crown's inner edge.
    /// The fields' clip, so day/night run under the filigree to the
    /// dial like the original's painted ground.
    @MainActor
    func plateDiscPath() -> Path {
        circle(center, radiusForDeclination(romanDialDec) + 3 * ui)
    }

    /// The day field — the sky above the horizon, as one fill circle.
    @MainActor
    func dayFieldPath() -> Path? {
        guard let h = almucantarCircle(altitude: .zero) else { return nil }
        return circle(h.centre, h.radius)
    }

    /// The full twilight annulus — horizon down to astronomical dark
    /// (0° → −18°), an even-odd circle pair: ONE warm AVRORA /
    /// CREPVSCVLVM glaze for the whole band.
    @MainActor
    func twilightBandPath() -> Path? {
        guard let h = almucantarCircle(altitude: .zero),
              let t = almucantarCircle(altitude: .degrees(-18)) else { return nil }
        var path = circle(h.centre, h.radius)
        path.addPath(circle(t.centre, t.radius))
        return path
    }

    /// Cumulative dusk veils — "below this altitude" at 0°, −6°, −12°,
    /// −18° (the horizon-scallop grammar: civil, nautical, astronomical).
    /// Each is plate-minus-circle, even-odd; STACKED in one ink they
    /// step the plate darker band by band, night wearing all four.
    @MainActor
    func duskVeilPaths() -> [Path] {
        [Angle.zero, .degrees(-6), .degrees(-12), .degrees(-18)].compactMap { alt in
            guard let c = almucantarCircle(altitude: alt) else { return nil }
            var path = plateDiscPath()
            path.addPath(circle(c.centre, c.radius))
            return path
        }
    }

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
        // NOX sits toward the observer's HIDDEN pole — the side of the
        // sky where the midnight sun passes below the horizon: due north
        // in the northern hemisphere, due south in the southern.
        let noxAzimuth: Double = latitude.radians >= 0 ? 0 : 180
        let specs: [(String, Double, Double)] = [
            ("ORTVS",        90,   5),
            ("AVRORA",       90,  -9),
            ("OCCASVS",     270,   5),
            ("CREPVSCVLVM", 270,  -9),
            ("NOX",  noxAzimuth, -24),
        ]
        // ▼ TWEAK per-character arc spacing (pt) ▼
        let spacing: CGFloat = 8 * ui
        let clip = radiusForDeclination(outerTropic) * 0.97

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
    /// as the horizon rim (Artist.horizonBump*, the DateCrown language).
    /// Inner edge stays a true circle (the dial side). Even-odd.
    /// ▼ TWEAK the band edges here ▼
    @MainActor
    func dialBandPath() -> Path {
        let roman  = radiusForDeclination(romanDialDec)
        let outerR = roman + 19 * ui
        let rect   = CGRect(x: center.x - outerR, y: center.y - outerR,
                            width: outerR * 2, height: outerR * 2)
        var path = Squircle(corners: Artist.shared.horizonBumpCorners,
                            bulge:   Artist.shared.horizonBumpBulge).path(in: rect)
        path.addPath(circle(center, roman + 3 * ui))
        return path
    }

    // MARK: Favourites & planets (the app's own marks on the plate)

    /// Remembered constellations, traced SOLID over the tympan — the
    /// postcard widget's hero treatment, here for every favourite.
    @MainActor
    func favouriteConstellationsPath() -> Path {
        let favs = Set(FavouritesStore().constellations())
        guard !favs.isEmpty else { return Path() }
        let clip = radiusForDeclination(romanDialDec) + 3
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
        let clip = radiusForDeclination(romanDialDec) + 3
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
        for (planet, vec, _, _) in PlanetPosition.allVectors(for: date,
                                                              siderealOffset: camera.sidereal) {
            guard let sc = camera.screen(rotatedEquatorial: vec) else { continue }
            let g = Artist.shared.planetGradient(planet)
            out.append((planet.name, sc, g.top, g.bottom))
        }
        return out
    }

    /// Phase that pins the ring like a CLOCK FACE: numeral XII (noon) at
    /// the TOP — the upper meridian, where the sun culminates — for every
    /// origin on Earth. The dial reads APPARENT SOLAR time: the Sun hand
    /// on XII IS local noon, ± the equation of time. (The retired civil
    /// phase anchored to the DEVICE timezone — fine at home, but browsing
    /// a far origin — a Sydney sky from a Rome device — spun the whole
    /// ring hours away from the tympan's solar geometry, so the numerals
    /// stopped registering with the horizon bands and labels.)
    var solarDialPhase: Double { -.pi }

    /// Roman numerals for the 24 SOLAR hours, positioned just outside
    /// the dial circle and rotated feet-to-centre, like the original.
    @MainActor
    func dialNumerals()
        -> [(id: Int, text: String, position: CGPoint, rotation: Angle)] {
        let r = radiusForDeclination(romanDialDec) + 11 * ui
        var out: [(Int, String, CGPoint, Angle)] = []
        for h in 0..<24 {
            let H = solarDialPhase + Double(h) / 24 * 2 * .pi
            guard let onRing = ringPoint(hourAngle: H, declination: romanDialDec)
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

    /// Zodiac band width — glyphs sit between the edge lines. Scales
    /// with the tile. ▼ TWEAK ▼
    var zodiacBandWidth: CGFloat { 16 * ui }

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
        var path = circle(ring.centre, ring.radius + zodiacBandWidth / 2)
        path.addPath(circle(ring.centre, ring.radius - zodiacBandWidth / 2))
        return path
    }

    /// The band's rim lines — outer and inner edge circles, exactly the
    /// annulus's own boundaries.
    @MainActor
    func zodiacEdgePaths() -> (outer: Path, inner: Path)? {
        guard let ring = eclipticCircle() else { return nil }
        return (circle(ring.centre, ring.radius + zodiacBandWidth / 2),
                circle(ring.centre, ring.radius - zodiacBandWidth / 2))
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
            let rIn  = ring.radius - zodiacBandWidth / 2
            let rOut = ring.radius + zodiacBandWidth / 2
            merged.move(to:    CGPoint(x: ring.centre.x + ux * rIn,
                                       y: ring.centre.y + uy * rIn))
            merged.addLine(to: CGPoint(x: ring.centre.x + ux * rOut,
                                       y: ring.centre.y + uy * rOut))
        }
        return merged
    }

    /// The 12 zodiac glyphs (ZodiacSign — Aries at λ 0°) at their sign
    /// midpoints on the band's CENTRELINE — between the rim lines — feet
    /// toward the ring's own centre, the original's orientation.
    @MainActor
    func zodiacGlyphs() -> [(id: Int, symbol: String, position: CGPoint, rotation: Angle)] {
        guard let ring = eclipticCircle() else { return [] }
        var out: [(Int, String, CGPoint, Angle)] = []
        for sign in ZodiacSign.zodiac {
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
        let (vec, _, _) = MoonPosition.vector(for: date, siderealOffset: camera.sidereal)
        return camera.screen(rotatedEquatorial: vec)
    }

    /// The Sun's hand — from the axle THROUGH the badge point, tip
    /// landing on the Roman dial, Prague's gesture: badge, hand and
    /// numeral read as one line. THIS is how the clock tells time.
    @MainActor
    func sunHandPath() -> Path? {
        sunPoint.map { handPath(through: $0,
                                radius: radiusForDeclination(romanDialDec)) }
    }

    /// The Moon's hand — the silver sibling, a touch shorter so the
    /// two never merge when the luminaries conjoin at new moon.
    @MainActor
    func moonHandPath() -> Path? {
        moonPoint.map { handPath(through: $0,
                                 radius: radiusForDeclination(romanDialDec) * 0.90) }
    }

    /// Axle → tip, the tip at `radius` along the axle→`p` direction —
    /// the badge rides the hand wherever the ecliptic puts it.
    private func handPath(through p: CGPoint, radius: CGFloat) -> Path {
        let dx  = p.x - center.x, dy = p.y - center.y
        let len = max(hypot(dx, dy), 0.0001)
        var hand = Path()
        hand.move(to: center)
        hand.addLine(to: CGPoint(x: center.x + dx / len * radius,
                                 y: center.y + dy / len * radius))
        return hand
    }

    // MARK: Sun helpers

    private var sunLambda: Angle { SunPosition.eclipticLongitude(for: date) }

    // MARK: Sampling helpers

    /// A full constant-declination circle, RA swept 0…2π.
    @MainActor
    private func sampledParallel(declination dec: Angle, steps: Int = 120) -> Path {
        var path = Path()
        var started = false
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let q = Precession.equatorialVector(ra: .radians(t * 2 * .pi), dec: dec)
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
        let q = Precession.equatorialVector(ra: .radians(lst.radians - H), dec: dec)
        return camera.screen(equatorial: q)
    }

    /// Closed-form declination-circle radius — valid ONLY as a
    /// rotation-agnostic distance-from-centre (clipping thresholds,
    /// plain circle outlines), never for placing a specific point.
    /// ρ = 2·tan(45°+δ/2) — the 2 is Projection's convention; `hemi`
    /// mirrors δ in the south, where the projection flings out the SCP
    /// and the radius formula runs the other way.
    private func radiusForDeclination(_ dec: Angle) -> CGFloat {
        camera.scale * 0.81 * CGFloat(2 * tan(.pi / 4 + hemi * dec.radians / 2))
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
struct OrlojPath: Shape {
    let source: Path
    func path(in rect: CGRect) -> Path { source }
}

/// The faux-glass treatment — `.glassEffect` doesn't render in the
/// widget process, so the look is hand-rolled from parts that rasterise
/// anywhere: a tinted body, a top-lit sheen, a bright top rim, and a
/// drop shadow for lift. ▼ TWEAK the glass recipe here ▼
struct GlassBand: View {
    let band:   Path
    var tint:   Color  = .white
    var tintOpacity:   Double = 0.10
    var eoFill: Bool   = false
    /// Host renders the widget as a LUMINANCE MAP (the tinted / "Clear"
    /// Home Screen themes): every fill becomes opaque white, so a stack of
    /// slab + sheen + casing + rim collapses into one fat white ring and
    /// swallows the instrument. In that mode the band is its outline only.
    var lineArt: Bool  = false

    var body: some View {
        let shape = OrlojPath(source: band)
        let style = FillStyle(eoFill: eoFill)
        if lineArt {
            // Stroking an even-odd band path traces BOTH its edges, which
            // is exactly the ring pair the filled version implies.
            shape.stroke(.white.opacity(0.9), lineWidth: 0.9)
        } else {
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
            shape.stroke(Artist.shared.canvasBackground.opacity(0.9),
                         lineWidth: Artist.shared.poiTextBorderWidth)
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
}

// MARK: - OrlojFaceLayers
// Composes the face back → front: star field (Canvas), the glass dial
// band, the plate/horizon/unequal-hour filigree, the dial scales, the
// glass zodiac band with its ticks, then the hands. Brass hairlines on
// glass slabs — the real instrument's construction. Shared by the iOS
// widget and the watch app — one instrument, two mounts.
struct OrlojFaceLayers: View {
    let face: OrlojFace
    /// Ink gain — 1 = the widget's postcard inks. The WATCH pushes past
    /// it: a tiny OLED read at wrist distance wants louder stars and
    /// hairlines than a Home Screen tile. Opacities scale toward 1,
    /// hairline widths grow at half rate, so the drawing stays filigree
    /// — brighter, not bolder. ▼ TWEAK per mount at the call site ▼
    var brilliance: Double = 1

    /// Draw as LINE ART for hosts that render the widget as a luminance
    /// map — iOS's tinted / "Clear" Home Screen themes. Fills, glows and
    /// shadows all resolve to solid white there, which bloats the face
    /// into mush; line art keeps the instrument readable. The full-colour
    /// render is untouched. ▼ set by the widget, never by the watch ▼
    var lineArt: Bool = false

    /// Opacity through the brilliance gain, clamped at full ink.
    private func ink(_ opacity: Double) -> Double {
        min(1, opacity * brilliance)
    }

    /// Hairline width through the gain — half-rate, so line weight
    /// creeps rather than doubles.
    private func heft(_ width: CGFloat) -> CGFloat {
        width * (1 + (brilliance - 1) * 0.5)
    }

    /// Mark fill — the badge-orb gradient in the body's canonical tints.
    /// A line-art host keeps only alpha (the palette flattens to a solid
    /// white slab), so the orb's shading is rebuilt in transparency alone
    /// — the same soft glass bead `POILabelView.badgeFill` wears on the
    /// postcard widget. ▼ TWEAK the masked softness here ▼
    private func markFill(top: Color, bottom: Color) -> LinearGradient {
        lineArt
        ? LinearGradient(colors: [.white.opacity(0.78), .white.opacity(0.38)],
                         startPoint: .bottom, endPoint: .top)
        : LinearGradient(colors: [top, bottom],
                         startPoint: .bottom, endPoint: .top)
    }

    /// Mark casing — canvas-navy in full colour; under line art the navy
    /// would come back a solid white ring, so it thins to a whisper of
    /// white rim instead, keeping the soft orb a bead on the plate.
    private var markCasing: Color {
        lineArt ? .white.opacity(0.5) : Artist.shared.canvasBackground.opacity(0.9)
    }

    /// One hand, in the badge grammar: navy casing under a metal fill,
    /// one true shadow for lift. Line art keeps only alpha, so there
    /// the hand is a single bright stroke — still the loudest line on
    /// the face, which is the whole point of a hand.
    @ViewBuilder
    private func handView(_ hand: Path, tint: Color, width: CGFloat) -> some View {
        if lineArt {
            OrlojPath(source: hand)
                .stroke(.white.opacity(0.85),
                        style: .init(lineWidth: width * 0.7, lineCap: .round))
        } else {
            ZStack {
                OrlojPath(source: hand)
                    .stroke(Artist.shared.canvasBackground.opacity(0.9),
                            style: .init(lineWidth: width + 1.2, lineCap: .round))
                OrlojPath(source: hand)
                    .stroke(tint,
                            style: .init(lineWidth: width, lineCap: .round))
            }
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
        }
    }

    private static let brass    = Color(red: 0.80, green: 0.66, blue: 0.38)
    private static let sunGold  = Color(red: 1.00, green: 0.82, blue: 0.45)
    private static let moonSilk = Color.white
    /// The SKY-side ink — horizon, twilight, unequal hours, ecliptic:
    /// everything that belongs to the heavens reads silver, while the
    /// instrument's own concentric metalwork stays gold.
    private static let silver   = Color(red: 0.78, green: 0.82, blue: 0.88)

    /// The numerals' voice — the same serif-semibold the POI labels use,
    /// as a concrete UIFont for OutlinedText's CoreText layout. Sized per
    /// tile (9pt large, ~5pt small — hard to read, adorable, as ordered).
    private static func numeralFont(size: CGFloat) -> UIFont {
        var desc = UIFont.systemFont(ofSize: size, weight: .semibold).fontDescriptor
        desc = desc.withDesign(.serif) ?? desc
        return UIFont(descriptor: desc, size: size)
    }

    var body: some View {
        let u = face.ui

        ZStack {
            // ── Tympan fields — day, twilight and night as MATERIAL,
            // not hairlines (the Prague read: you see which field the
            // Sun stands in). A faint lift over the day, one warm
            // AVRORA/CREPVSCVLVM glaze across the twilight annulus,
            // and four stacked dusk veils stepping the plate darker
            // to night. The horizon is the EDGE between fields — no
            // stroke. Painted ground, so everything rides above it.
            // A luminance-map host would invert the veils (black
            // fills come back WHITE, dawn glowing at midnight), so
            // line art draws the horizon as the one honest line.
            if lineArt {
                if let horizon = face.dayFieldPath() {
                    OrlojPath(source: horizon)
                        .stroke(.white.opacity(0.4), lineWidth: 0.8)
                        .clipShape(OrlojPath(source: face.plateDiscPath()))
                }
            } else {
                Group {
                    if let day = face.dayFieldPath() {
                        OrlojPath(source: day)
                            .fill(.white.opacity(ink(0.06)))
                    }
                    if let dusk = face.twilightBandPath() {
                        OrlojPath(source: dusk)
                            .fill(Self.sunGold.opacity(ink(0.09)),
                                  style: FillStyle(eoFill: true))
                    }
                    ForEach(Array(face.duskVeilPaths().enumerated()),
                            id: \.offset) { _, veil in
                        OrlojPath(source: veil)
                            .fill(.black.opacity(0.10),
                                  style: FillStyle(eoFill: true))
                    }
                }
                .clipShape(OrlojPath(source: face.plateDiscPath()))
            }

            // The sky behind the instrument.
            Canvas { ctx, size in
                face.drawStars(in: &ctx, size: size, gain: brilliance)
            }

            // Remembered constellations — traced solid, the postcard
            // widget's hero treatment for every favourite.
            OrlojPath(source: face.favouriteConstellationsPath())
                .stroke(Self.silver.opacity(ink(0.45)),
                        style: .init(lineWidth: heft(1), lineCap: .round, lineJoin: .round))

            // ── The wanderers and the remembered — the app's OWN
            // marks, badge grammar and all: spectral PENTAGON
            // squircles for favourite stars, canonical-tint rounded
            // squircles for the seven planets, each with the badge's
            // gradient fill, dark casing, and soft glow.
            ForEach(face.favouriteStarMarks(), id: \.id) { mark in
                Squircle(corners: 5, bulge: Artist.shared.poiBadgeBulge)
                    .fill(markFill(top: mark.top, bottom: mark.bottom))
                    .overlay(
                        Squircle(corners: 5, bulge: Artist.shared.poiBadgeBulge)
                            .stroke(markCasing, lineWidth: 1.1)
                    )
                    .frame(width: 9 * u, height: 9 * u)
                    .shadow(color: mark.top.opacity(0.5), radius: lineArt ? 0 : 1.5)
                    .position(mark.position)
            }


            // ── Fixed dial band (glass) — the real clock's black
            // outer ring, smoky so the sky reads through it.
            GlassBand(band: face.dialBandPath(),
                      tint: .black, tintOpacity: 0.30, eoFill: true,
                      lineArt: lineArt)
            .shadow(radius: lineArt ? 0 : 4, y: lineArt ? 0 : 2.5)

            // ── Plate filigree.
            ForEach(Array(face.platePaths().enumerated()), id: \.offset) { _, plate in
                OrlojPath(source: plate.path)
                    .stroke(Self.brass.opacity(ink(0.85)), lineWidth: heft(plate.width))
            }
            // (The −18° twilight hairline is retired — the tympan
            // fields' own edges bound AVRORA/CREPVSCVLVM now.)
            OrlojPath(source: face.unequalHoursPath())
                .stroke(Self.silver.opacity(ink(0.5)), lineWidth: heft(0.5))

            // Tympan region labels — the original's Latin, laid out
            // character by character ALONG their bands' curves, with
            // the app's dark casing so they hold up at a squint.
            ForEach(face.tympanLabelChars(), id: \.id) { glyph in
                Text(glyph.char)
                    .font(.system(size: max(3.5, 6.5 * u), weight: .medium, design: .serif))
                    .foregroundStyle(Self.silver.opacity(ink(0.8)))
                    .shadow(color: Artist.shared.canvasBackground.opacity(0.9),
                            radius: lineArt ? 0 : 1)
                    .rotationEffect(glyph.rotation)
                    .position(glyph.position)
            }

            // ── The crown carries NUMERALS ALONE, in the app's label
            // voice: OutlinedText — serif brass with the real dark
            // casing, crisp at any zoom, squint-proof. Phased SOLAR —
            // XII up = local noon, so the ring registers with the
            // tympan for any origin (see `solarDialPhase`).
            ForEach(face.dialNumerals(), id: \.id) { numeral in
                Group {
                    if lineArt {
                        // Fill + casing both resolve to white and merge —
                        // the numerals turn into solid blocks. Plain glyphs.
                        Text(numeral.text)
                            .font(.system(size: 9 * u, weight: .semibold,
                                          design: .serif))
                            .foregroundStyle(.white)
                    } else {
                        OutlinedText(text:      numeral.text,
                                     fill:      Self.brass,
                                     stroke:    Artist.shared.canvasBackground,
                                     lineWidth: max(0.7, 1.2 * u),
                                     font:      Self.numeralFont(size: 9 * u))
                    }
                }
                .rotationEffect(numeral.rotation)
                .position(numeral.position)
            }
            // ── Rete: the zodiac band — smoky dark glass like the
            // original's black ring, its RIM LINES traced silver
            // (outer leading, inner echoed), sign dividers spanning
            // rim to rim, and GOLD glyphs between the rims with a
            // hard dark shadow (Prague's gold-on-black, boom).
            GlassBand(band: face.zodiacBandPath(),
                      tint: .black, tintOpacity: 0.35, eoFill: true,
                      lineArt: lineArt)
            .shadow(radius: lineArt ? 0 : 4, y: lineArt ? 0 : 2.5)
            if let edges = face.zodiacEdgePaths() {
                OrlojPath(source: edges.outer)
                    .stroke(Self.silver.opacity(ink(0.85)), lineWidth: heft(1))
                OrlojPath(source: edges.inner)
                    .stroke(Self.silver.opacity(ink(0.65)), lineWidth: heft(0.8))
            }
            OrlojPath(source: face.zodiacTicksPath())
                .stroke(Self.silver.opacity(ink(0.6)), lineWidth: heft(0.8))
            ForEach(face.zodiacGlyphs(), id: \.id) { glyph in
                Text(glyph.symbol)
                    .font(.system(size: 11 * u, weight: .bold))
                    .foregroundStyle(Self.silver)
                    .shadow(color: .black.opacity(0.9), radius: lineArt ? 0 : 1, y: lineArt ? 0 : 0.5)
                    .rotationEffect(glyph.rotation)
                    .position(glyph.position)
            }

            ForEach(face.planetMarks(), id: \.id) { mark in
                Squircle(corners: 4, bulge: 2.0)
                    .fill(markFill(top: mark.top, bottom: mark.bottom))
                    .overlay(
                        Squircle(corners: 4, bulge: 2.0)
                            .stroke(markCasing, lineWidth: 1)
                    )
                    .frame(width: 7 * u, height: 7 * u)
                    .shadow(color: mark.top.opacity(0.45), radius: lineArt ? 0 : 1.2)
                    .position(mark.position)
            }


            // ── Hands — SOLID MATERIAL, the Prague gesture: brass
            // for the Sun, silver for the Moon, each running from the
            // axle THROUGH its badge to the Roman dial, so badge,
            // hand and numeral read as one line. The only elements
            // loud enough for a real shadow — they answer "what time
            // is it"; everything else is scenery. Badges ride on top.
            if let hand = face.sunHandPath() {
                handView(hand, tint: Self.brass,   width: 2.0 * u)
            }
            if let hand = face.moonHandPath() {
                handView(hand, tint: Self.silver,  width: 1.5 * u)
            }
            // The axle — a small brass hub grounding both hands.
            Circle()
                .fill(lineArt ? AnyShapeStyle(Color.white.opacity(0.85))
                              : AnyShapeStyle(Self.brass))
                .overlay(Circle().stroke(markCasing, lineWidth: 1))
                .frame(width: 6 * u, height: 6 * u)
                .position(face.center)
            if let sun = face.sunPoint {
                POILabelView(category:   .sun,
                             text:       "",
                             labelStyle: .star,
                             nameReveal: 0,
                             borderScaleCompensation: 1 / max(0.55, u))
                    .scaleEffect(max(0.55, u))
                    .position(sun)
            }
            if let moon = face.moonPoint {
                POILabelView(category:   .moon,
                             text:       "",
                             labelStyle: .planetoids,
                             nameReveal: 0,
                             borderScaleCompensation: 1 / max(0.55, u),
                             moonPhase:  MoonPosition.phase(for: face.date,
                                                            latitude: face.latitude))
                    .scaleEffect(max(0.55, u))
                    .position(moon)
            }
        }
        .scaleEffect(0.95)
    }
}

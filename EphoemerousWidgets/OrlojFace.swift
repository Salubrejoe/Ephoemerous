import SwiftUI
import CoreText
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
    /// The JWST's direction (equatorial of date) for this instant, when the
    /// host has its track — the one spacecraft slow enough for a clock that
    /// steps every quarter hour. `nil` = not drawn (the watch, no data).
    let jwst:      SIMD3<Double>?
    let lst:       Angle
    let latitude:  Angle
    let longitude: Angle
    /// UI scale — 1 on the large tile, ~0.46 on the small one (and the
    /// watch). The PROJECTION scales itself (everything derives from
    /// `size`); this factor shrinks the fixed-point dressing — fonts,
    /// band widths, marks — so the whole instrument miniaturises
    /// coherently.
    let ui:        CGFloat

    /// TYPE scale — `ui` with a floor.
    ///
    /// `ui` shrinks every fixed dimension linearly, which is right for band
    /// widths, marks and strokes and WRONG for glyphs. A 45mm watch is
    /// ~198pt on its short side, so `ui` ≈ 0.58 and the Roman numerals
    /// render at ~5pt — less than half the wrist's legibility floor. The
    /// face was scaled as though a watch were a small widget; it isn't.
    /// Density should fall at the small end, not letter height.
    ///
    /// The floor is what the CURRENT circular dial can carry: 24 numerals
    /// on a ring of radius ~103pt gives each a ~27pt slot, and "VIII" in
    /// 9pt serif semibold runs ~20pt wide. Going much past this needs a
    /// bigger ring, not a bigger floor. ▼ TWEAK the smallest type here ▼
    let type:      CGFloat

    /// The WRIST face — the same instrument, reduced for a screen a third
    /// the size. The crown, the hand and the plate clip all stay; what goes
    /// is filigree the small screen can't spend ink on (tropic circles,
    /// zodiac sign dividers) and 23 of the 24 numerals.
    ///
    /// The dial keeps ONE numeral: the hour the Sun's hand is nearest. The
    /// crown still reads as a dial — band, ring, a numeral the hand points
    /// at — but the ring stops being 24 competing 8pt glyphs and becomes a
    /// single legible mark. Everything else about the crown is unchanged.
    let wrist:     Bool

    /// Radius of the ring the Roman numerals' centres sit on.
    let numeralRadius: CGFloat

    /// The clock the numerals keep: the PLACE's own time zone, not the
    /// phone's — it's a clock of where the sky is drawn.
    let civilCalendar: Calendar

    /// Which ring of hours the glass face wears (see `NumeralRing`).
    /// ▼ TWEAK the default here ▼
    var numeralRing: NumeralRing = .roman

    /// Tropic circles and zodiac sign dividers — two greys among the
    /// ecliptic, the horizon and the plate edge. Dropped on the wrist.
    var showsFiligree: Bool { !wrist }

    /// The hour the Sun's hand is NEAREST — the wrist face's only numeral.
    /// Rounded, not floored, so the numeral shown is always the closest
    /// marker to the hand rather than the one it last passed. Same civil
    /// clock `dialNumerals` phases the ring against.
    var sunHour: Int {
        let c = civilCalendar.dateComponents([.hour, .minute, .second], from: date)
        let civil = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
                  + Double(c.second ?? 0) / 3600
        return Int(civil.rounded()) % 24
    }

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
    init(date: Date, origin: (latDeg: Double, lonDeg: Double)?, size: CGSize,
         wrist: Bool = false, jwst: SIMD3<Double>? = nil, timeZone: TimeZone = .current) {
        self.wrist = wrist
        var civil = Calendar(identifier: .gregorian)
        civil.timeZone = timeZone
        self.civilCalendar = civil
        self.jwst  = jwst
        self.date = date
        // Prague fallback before the app has ever backgrounded — apt for
        // the one face that's explicitly styled after this city's clock.
        let lat = Angle.degrees(origin?.latDeg ?? 50.09)
        let lon = Angle.degrees(origin?.lonDeg ?? 14.42)
        latitude  = lat
        longitude = lon
        lst = Precession.lst(for: date, longitude: lon)
        ui   = min(1, min(size.width, size.height) / 340)   // systemLarge ≈ 1
        type = max(0.92, ui)

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
        // The numerals keep their ring. The wrist sizes the projection to
        // the Roman dial; the glass face sizes it so the outer tropic —
        // the plate's edge — stops just short of the numerals' feet.
        numeralRadius = 0.81 * targetOuterRadius + 11 * ui
        let scale: CGFloat
        if wrist {
            scale = targetOuterRadius / CGFloat(romanRho)
        } else {
            let plateEdge = numeralRadius - 0.36 * Self.glassNumeralSize(ui: ui, type: type)
                          - Self.plateNumeralGap * ui
            scale = plateEdge / CGFloat(Self.tropicRho)
        }

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
        // Below the equator the glass face is mirrored, so its hours run
        // clockwise like any clock (see `SkyCamera.mirrored`). The wrist
        // keeps the sky as seen.
        let mirrored  = !wrist && lat.radians < 0
        let unrotated = SkyCamera(scale: scale, offset: .zero, size: size,
                                 viewpoint: viewpoint, sidereal: sidereal, mirrored: mirrored)
        var rotation = Angle.zero
        let c = unrotated.screen(.zero)
        if let probe = unrotated.screen(
            equatorial: Precession.equatorialVector(ra: lst, dec: .zero)) {
            let theta = atan2(Double(probe.y - c.y), Double(probe.x - c.x))
            rotation = .radians(-Double.pi / 2 - theta)
        }

        camera = SkyCamera(scale: scale, offset: .zero, rotation: rotation,
                          size: size, viewpoint: viewpoint, sidereal: sidereal, mirrored: mirrored)
    }

    var center: CGPoint { camera.screen(.zero) }

    // MARK: Star field (stays Canvas-drawn — hundreds of dots, no glass)

    /// Faint naked-eye field — kept sparse (mag ≤ 4.6) so the dial
    /// geometry stays the thing you actually read. Drawn in the app's own
    /// field-star style (see `Artist+StarField`) — grey squircles, named
    /// stars a step above the nameless, the glow — at the dial's size.
    @MainActor
    func drawStars(in ctx: inout GraphicsContext, size: CGSize, gain: Double = 1) {
        // The small tile takes a sparser field (mag 3.8) — the same dot
        // count at a quarter the area would read as fog, not sky.
        let magLimit = ui < 0.7 ? 3.8 : 4.6
        let a        = Artist.shared
        let zenith   = camera.viewpoint.originVector
        for star in Self.starField where star.magnitude <= magLimit {
            guard let sc = camera.screen(equatorial: star.equatorialVector),
                  sc.x > -4, sc.x < size.width + 4,
                  sc.y > -4, sc.y < size.height + 4 else { continue }
            // ▼ TWEAK the dial's field: size and strength ▼
            a.drawFieldStar(ctx,
                            at:           sc,
                            magnitude:    star.magnitude,
                            named:        star.properName != nil,
                            scale:        camera.scale,
                            gain:         gain,
                            sizeScale:    0.6 * ui,
                            aboveHorizon: simd_dot(star.equatorialVector.sidereallyRotated(by: camera.sidereal),
                                                   zenith) > 0)
        }
    }

    // MARK: Plate (fixed)

    /// Tropic of Capricorn (inner), equator, Tropic of Cancer (outer) —
    /// each with its stroke weight, the equator emphasised.
    @MainActor
    func platePaths() -> [(path: Path, width: CGFloat)] {
        [(sampledParallel(declination: AstroConstants.tropicCancer), 0.2),
        (sampledParallel(declination: AstroConstants.tropicCapricorn), 0.2),
//         (sampledParallel(declination: .zero),                          0.9),
//         (sampledParallel(declination: AstroConstants.tropicCancer),    0.5)
        ]
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
        var merged = Path()
        for k in 0...12 {
            merged.addLines(unequalHourLine(Double(k) / 12, from: innerTropic, to: outerTropic))
        }
        return merged
    }

    /// The day's twelve unequal hours as fillable sections, the first hour
    /// first: the sky between two hour lines, from the inner tropic out
    /// past the widget's corners (the plate's clip trims them). The first
    /// and last lines ARE the horizon, so the sections tile the day.
    @MainActor
    func unequalHourSections() -> [Path] {
        let beyond = Angle.radians(hemi * Self.sectionReach.radians)
        return (0..<12).map { k in
            let from = Double(k) / 12, to = Double(k + 1) / 12
            var section = Path()
            section.addLines(unequalHourLine(from, from: innerTropic, to: beyond)
                           + unequalDayParallel(beyond, from: from, to: to)
                           + unequalHourLine(to, from: innerTropic, to: beyond).reversed()
                           + unequalDayParallel(innerTropic, from: to, to: from))
            section.closeSubpath()
            return section
        }
    }

    /// How far out the sections run — a declination whose circle clears
    /// the widget's corners. ▼ TWEAK ▼
    private static let sectionReach = Angle.degrees(60)

    /// The inner tropic under the current projection — Capricorn in the
    /// north, Cancer in the south: the edge of the Earth's disc.
    private var innerTropic: Angle {
        .radians(hemi * AstroConstants.tropicCapricorn.radians)
    }

    /// The two tropics as thin rings, for glass: each parallel
    /// stroked into a band `width` wide. ▼ TWEAK the width ▼
    @MainActor
    func plateRingPaths() -> [Path] {
        let width = 1.6 * ui + 0.6
        // Inner, then outer — whichever tropic each is in this hemisphere.
        return [innerTropic, outerTropic].map { dec in
            var parallel = sampledParallel(declination: dec, steps: 240)
            parallel.closeSubpath()
            return parallel.strokedPath(StrokeStyle(lineWidth: width))
        }
    }

    /// The Earth's disc at the centre of the plate — everything inside
    /// the inner tropic, as on the original.
    @MainActor
    func earthDiscPath() -> Path {
        var disc = sampledParallel(declination: innerTropic)
        disc.closeSubpath()
        return disc
    }

    // MARK: The Earth (2.0)
    // The planet at the centre — the Orloj is geocentric. It is seen from
    // space straight above the OBSERVER, so the axle pierces it exactly
    // where they stand. It is turned the way the face is: the way to the
    // noon Sun (toward the equator) points up, and east lies on the side
    // where the face's morning is — south-up with east on the left in the
    // north, the mirror of that in the south, never a mirrored map. So the
    // day side always faces the Sun hand.

    /// The globe's radius: part of the open centre, leaving a ring of
    /// space inside the inner tropic — more of it on the large face, where
    /// the rete has room to breathe. ▼ TWEAK ▼
    var earthRadius: CGFloat {
        (ui >= 0.7 ? 0.45 : 0.62) * camera.scale * CGFloat(2 * tan(.pi / 4 - AstroConstants.tropicCancer.radians / 2))
    }

    /// The globe's limb.
    func earthGlobePath() -> Path { circle(center, earthRadius) }

    /// How hour angles lie round the axle: screen angle θ(H) = zero + sense·H.
    @MainActor
    private var hourAngleFrame: (zero: Double, sense: Double) {
        guard let a = ringPoint(hourAngle: 0,   declination: .zero),
              let b = ringPoint(hourAngle: 0.1, declination: .zero)
        else { return (-.pi / 2, 1) }
        let t0 = atan2(Double(a.y - center.y), Double(a.x - center.x))
        let t1 = atan2(Double(b.y - center.y), Double(b.x - center.x))
        return (t0, atan2(sin(t1 - t0), cos(t1 - t0)) >= 0 ? 1 : -1)
    }

    /// A place on Earth (latitude, longitude in radians, east positive)
    /// as a unit vector fixed to the Earth.
    private static func earthVector(latitude φ: Double, longitude λ: Double) -> SIMD3<Double> {
        SIMD3(cos(φ) * cos(λ), cos(φ) * sin(λ), sin(φ))
    }

    /// The globe's view: Earth-fixed vectors → x, y along the screen, z
    /// toward the viewer (the observer's zenith).
    private struct GlobeView {
        let east, north, zenith: SIMD3<Double>      // the observer's local axes
        let eastOnScreen, northOnScreen: SIMD2<Double>

        func callAsFunction(_ p: SIMD3<Double>) -> SIMD3<Double> {
            let e = simd_dot(p, east), n = simd_dot(p, north)
            let xy = e * eastOnScreen + n * northOnScreen
            return SIMD3(xy.x, xy.y, simd_dot(p, zenith))
        }
    }

    @MainActor
    private var globeView: GlobeView {
        let φ = latitude.radians, λ = longitude.radians
        let frame = hourAngleFrame
        // Up the face is toward noon — toward the equator; east is where
        // the morning hour angles lie.
        let noon  = SIMD2(cos(frame.zero), sin(frame.zero))
        let morning = frame.zero - frame.sense * .pi / 2
        return GlobeView(east:   SIMD3(-sin(λ), cos(λ), 0),
                         north:  SIMD3(-sin(φ) * cos(λ), -sin(φ) * sin(λ), cos(φ)),
                         zenith: Self.earthVector(latitude: φ, longitude: λ),
                         eastOnScreen:  SIMD2(cos(morning), sin(morning)),
                         northOnScreen: -hemi * noon)
    }

    /// A view vector's place on the face.
    private func onGlobe(_ v: SIMD3<Double>) -> CGPoint {
        CGPoint(x: center.x + CGFloat(v.x) * earthRadius, y: center.y + CGFloat(v.y) * earthRadius)
    }

    /// The subsolar point, in the globe's view.
    @MainActor
    private var subsolarVector: SIMD3<Double> {
        let sun = SIMD3<Double>.eclipticPoint(lambda: sunLambda)
        let hourAngle = lst.radians - atan2(sun.y, sun.x)
        return globeView(Self.earthVector(latitude:  asin(max(-1, min(1, sun.z))),
                                          longitude: longitude.radians - hourAngle))
    }

    /// Where the Sun stands overhead, on the globe — the brightest point
    /// of the day side (on the limb's far side, it shows at the limb).
    @MainActor
    var subsolarPoint: CGPoint { onGlobe(subsolarVector) }

    /// The continents on the visible hemisphere (see `OrlojLand`). Where a
    /// landmass runs over the limb it is cut, and the cut follows the limb.
    @MainActor
    func earthLandPath() -> Path {
        let view = globeView
        var path = Path()
        for ring in OrlojLand.rings {
            let vectors = ring.map { view(Self.earthVector(latitude:  $0.y * .pi / 180,
                                                           longitude: $0.x * .pi / 180)) }
            let visible = Self.visiblePart(of: vectors)
            guard visible.count >= 3 else { continue }
            path.addLines(visible.map(onGlobe))
            path.closeSubpath()
        }
        return path
    }

    // MARK: The ground (2.0)
    // Everything inside the horizon circle is BELOW the observer's feet —
    // Prague paints it black as NOX. Here it is the Earth: the whole world
    // as an azimuthal map centred on the observer, laid into the sky below
    // the horizon, the edge of their half of the globe on the horizon.
    //
    // The axle is the sky's hidden pole, not the observer's nadir, so the
    // map is built to put the observer ON the axle: their hemisphere is
    // projected stereographically onto a disc (the astrolabe's own map —
    // conformal, circles stay circles), then slid inside that disc by a
    // Möbius transformation until they sit where the pole does, and laid
    // below the horizon. The rim stays on the horizon; bearings stay true
    // along the meridian and bend a little elsewhere.

    /// How far round the world the map runs: the half of the globe centred
    /// on the observer. ▼ TWEAK ▼
    private static let groundReach: Double = .pi / 2

    /// The slide's largest reach: near the equator the hidden pole sits on
    /// the horizon itself, and the observer would be pushed to the rim. ▼ TWEAK ▼
    private static let groundSlideCap: Double = 0.85

    /// Where the observer stands on the face: the nadir, straight below.
    @MainActor
    var nadirPoint: CGPoint? {
        camera.screen(rotatedEquatorial: camera.viewpoint.skyPoint(azimuth: 0, altitude: -.pi / 2))
    }

    /// The sky below the horizon, inside the outer tropic.
    @MainActor
    func groundPath() -> Path {
        guard let h = almucantarCircle(altitude: .zero) else { return Path() }
        return circle(h.centre, h.radius).intersection(plateFillPath())
    }

    /// The continents, mapped onto the ground.
    @MainActor
    func groundLandPath() -> Path {
        let φo = latitude.radians, λo = longitude.radians
        let east   = SIMD3<Double>(-sin(λo), cos(λo), 0)
        let north  = SIMD3<Double>(-sin(φo) * cos(λo), -sin(φo) * sin(λo), cos(φo))
        let zenith = Self.earthVector(latitude: φo, longitude: λo)
        let rim    = cos(Self.groundReach)
        // Where the axle sits in the hemisphere's stereographic disc: toward
        // the hidden pole's bearing, tan((90° − |φ|) / 2) out — so the
        // observer, slid there, lands under the axle.
        let poleBearing: Double = φo >= 0 ? .pi : 0
        let reach = min(tan((.pi / 2 - abs(φo)) / 2), Self.groundSlideCap)
        let slide = SIMD2(reach * sin(poleBearing), reach * cos(poleBearing))   // (east, north)
        var path   = Path()
        for ring in OrlojLand.rings {
            // Each place in the observer's frame: x east, y north, z up.
            let local = Self.densified(ring.map { place -> SIMD3<Double> in
                let p = Self.earthVector(latitude: place.y * .pi / 180, longitude: place.x * .pi / 180)
                return SIMD3(simd_dot(p, east), simd_dot(p, north), simd_dot(p, zenith))
            })
            let kept = Self.clipped(local, aboveZ: rim)
            guard kept.count >= 3 else { continue }
            let points = kept.compactMap { v -> CGPoint? in
                // Stereographic from the antipode: the observer at 0, the
                // hemisphere's edge on the unit circle…
                let w = SIMD2(v.x, v.y) / (1 + v.z)
                // …slid by the Möbius map w ↦ (w + a) / (1 + ā·w)…
                let m = Self.mobius(w, slide)
                // …and read back as a direction below the horizon.
                let fromNadir = 2 * atan(simd_length(m))
                let q = camera.viewpoint.skyPoint(azimuth:  atan2(m.x, m.y),
                                                  altitude: fromNadir - .pi / 2)
                return camera.screen(rotatedEquatorial: q)
            }
            guard points.count >= 3 else { continue }
            path.addLines(points)
            path.closeSubpath()
        }
        return path.intersection(groundPath())
    }

    /// The disc automorphism w ↦ (w + a) / (1 + ā·w), in complex arithmetic
    /// on (x, y) pairs: carries 0 to a and the unit circle onto itself.
    private static func mobius(_ w: SIMD2<Double>, _ a: SIMD2<Double>) -> SIMD2<Double> {
        let num = w + a
        // 1 + conj(a)·w
        let den = SIMD2(1 + a.x * w.x + a.y * w.y, a.x * w.y - a.y * w.x)
        let d2  = den.x * den.x + den.y * den.y
        return SIMD2((num.x * den.x + num.y * den.y) / d2, (num.y * den.x - num.x * den.y) / d2)
    }

    /// A ring with no edge longer than ~1.5°, so it bends with the map.
    private static func densified(_ ring: [SIMD3<Double>]) -> [SIMD3<Double>] {
        guard let last = ring.last else { return [] }
        var out: [SIMD3<Double>] = []
        var previous = last
        for v in ring {
            let angle = acos(max(-1, min(1, simd_dot(previous, v))))
            let steps = Int(angle / (1.5 * .pi / 180))
            if steps > 1 {
                for k in 1..<steps {
                    out.append(simd_normalize(previous + (v - previous) * (Double(k) / Double(steps))))
                }
            }
            out.append(v)
            previous = v
        }
        return out
    }

    /// A ring cut to the cap z ≥ `aboveZ`, its cuts bridged along the cap's
    /// edge the shorter way round.
    private static func clipped(_ ring: [SIMD3<Double>], aboveZ zc: Double) -> [SIMD3<Double>] {
        guard let start = ring.firstIndex(where: { $0.z >= zc }) else { return [] }
        let walk = Array(ring[start...] + ring[..<start]) + [ring[start]]
        let edge = sqrt(max(0, 1 - zc * zc))
        func onEdge(_ a: Double) -> SIMD3<Double> { SIMD3(edge * sin(a), edge * cos(a), zc) }
        func crossing(_ p: SIMD3<Double>, _ q: SIMD3<Double>) -> Double {
            let c = p + (q - p) * ((p.z - zc) / (p.z - q.z))
            return atan2(c.x, c.y)
        }
        var out: [SIMD3<Double>] = [walk[0]]
        var exit: Double?
        for (p, q) in zip(walk, walk.dropFirst()) {
            switch (p.z >= zc, q.z >= zc) {
            case (true, true):
                out.append(q)
            case (true, false):
                exit = crossing(p, q)
                out.append(onEdge(exit!))
            case (false, true):
                let entry = crossing(p, q)
                if let from = exit {
                    let span  = atan2(sin(entry - from), cos(entry - from))
                    let steps = max(Int(abs(span) / 0.05), 1)
                    for k in 1..<steps { out.append(onEdge(from + span * Double(k) / Double(steps))) }
                }
                out.append(onEdge(entry))
                out.append(q)
                exit = nil
            case (false, false):
                break
            }
        }
        return out
    }

    /// A ring of view vectors clipped to the near hemisphere (z ≥ 0): where
    /// it passes behind the limb it is cut, and the gap is bridged round
    /// the limb itself, the shorter way.
    private static func visiblePart(of ring: [SIMD3<Double>]) -> [SIMD3<Double>] {
        guard let start = ring.firstIndex(where: { $0.z >= 0 }) else { return [] }
        let walk = Array(ring[start...] + ring[..<start]) + [ring[start]]
        func crossing(_ p: SIMD3<Double>, _ q: SIMD3<Double>) -> SIMD3<Double> {
            let c = p + (q - p) * (p.z / (p.z - q.z))
            let h = simd_normalize(SIMD2(c.x, c.y))
            return SIMD3(h.x, h.y, 0)
        }
        var out: [SIMD3<Double>] = [walk[0]]
        var exit: SIMD3<Double>?
        for (p, q) in zip(walk, walk.dropFirst()) {
            switch (p.z >= 0, q.z >= 0) {
            case (true, true):
                out.append(q)
            case (true, false):
                exit = crossing(p, q)
                out.append(exit!)
            case (false, true):
                let entry = crossing(p, q)
                if let from = exit {
                    let a0 = atan2(from.y, from.x)
                    let span = atan2(sin(atan2(entry.y, entry.x) - a0), cos(atan2(entry.y, entry.x) - a0))
                    let steps = max(Int(abs(span) / 0.05), 1)
                    for k in 1..<steps {
                        let a = a0 + span * Double(k) / Double(steps)
                        out.append(SIMD3(cos(a), sin(a), 0))
                    }
                }
                out.append(entry)
                out.append(q)
                exit = nil
            case (false, false):
                break
            }
        }
        return out
    }

    /// The night side of the visible hemisphere: bounded by the terminator
    /// (a great circle, seen from above the pole as half an ellipse) and
    /// the limb on the side away from the Sun.
    @MainActor
    func earthNightPath() -> Path {
        let s  = subsolarVector
        guard simd_length(SIMD2(s.x, s.y)) > 1e-6 else {       // Sun straight overhead or underfoot
            return s.z > 0 ? Path() : earthGlobePath()
        }
        let sh = simd_normalize(SIMD2(s.x, s.y))               // the Sun's bearing
        let e  = SIMD3<Double>(-sh.y, sh.x, 0)                  // where the terminator meets the limb
        let w  = simd_normalize(SIMD3<Double>(0, 0, 1) - s.z * s)   // its highest point
        let anti = SIMD3<Double>(-sh.x, -sh.y, 0)               // the limb's midnight
        let steps = 48
        let terminator = (0...steps).map { i -> SIMD3<Double> in
            let t = Double.pi * Double(i) / Double(steps)
            return cos(t) * e + sin(t) * w
        }
        let limb = (0...steps).map { i -> SIMD3<Double> in
            let t = Double.pi * Double(i) / Double(steps)
            return cos(t) * -e + sin(t) * anti
        }
        var path = Path()
        path.addLines((terminator + limb).map(onGlobe))
        path.closeSubpath()
        return path
    }

    /// One unequal hour line, `frac` of the way through the day, walked
    /// across declinations: at each, the same fraction of that parallel's
    /// day arc. Where a parallel never sets (or never rises) the arc is
    /// all of it (or none).
    @MainActor
    private func unequalHourLine(_ frac: Double, from a: Angle, to b: Angle,
                                 steps: Int = 48) -> [CGPoint] {
        (0...steps).compactMap { i in
            let dec = Angle.radians(a.radians + (b.radians - a.radians) * Double(i) / Double(steps))
            let hSet = Self.daySemiArc(declination: dec, latitude: latitude)
            return ringPoint(hourAngle: -hSet + frac * 2 * hSet, declination: dec)
        }
    }

    /// Along one parallel's day arc between two fractions of the day.
    @MainActor
    private func unequalDayParallel(_ dec: Angle, from a: Double, to b: Double,
                                    steps: Int = 12) -> [CGPoint] {
        let hSet = Self.daySemiArc(declination: dec, latitude: latitude)
        return (0...steps).compactMap { i in
            let frac = a + (b - a) * Double(i) / Double(steps)
            return ringPoint(hourAngle: -hSet + frac * 2 * hSet, declination: dec)
        }
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
                // Stopping short of both stars, at the dial's star size.
                let art = Artist.shared
                let gap = { (s: Star) in (art.fieldStarRadius(magnitude: s.magnitude, scale: self.camera.scale)
                                          + art.figureGapMargin) * 0.6 * self.ui }
                guard let (p, q) = art.figureSegment(from: a, to: b, gapA: gap(seg.a), gapB: gap(seg.b))
                else { continue }
                merged.move(to: p)
                merged.addLine(to: q)
            }
        }
        return merged
    }

    /// Remembered stars as the app's tier-0 mark: the tiny SPECTRAL
    /// PENTAGON squircle (PinnedStarDots' below-badge-tier form).
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

    /// The seven planets — riding the ecliptic through the rete, like the
    /// wanderers they are — each worn as the app's own badge.
    @MainActor
    func planetMarks() -> [(id: String, position: CGPoint, planet: Planet)] {
        var out: [(String, CGPoint, Planet)] = []
        for (planet, vec, _, _) in PlanetPosition.allVectors(for: date,
                                                              siderealOffset: camera.sidereal) {
            guard let sc = camera.screen(rotatedEquatorial: vec) else { continue }
            out.append((planet.name, sc, planet))
        }
        return out
    }

    /// Roman numerals for the 24 hours, positioned just outside the
    /// dial circle and rotated feet-to-centre, like the original.
    ///
    /// The crown reads CIVIL time — the device's wall clock, BST and
    /// all — anchored through the Sun itself: the hand sits at the
    /// Sun's true hour angle and the wall clock says `civilNow`, so
    /// numeral h belongs at the hour angle the Sun will hold at civil
    /// hour h. Longitude, the equation of time and DST all fold into
    /// that one subtraction; the hand on X IS ten o'clock on your
    /// phone, by construction. (An earlier civil phase anchored to
    /// the raw timezone offset was retired for detaching the ring
    /// from the tympan's solar geometry; deriving from the Sun's OWN
    /// hour angle can't — the rotation changes WHICH numerals are
    /// daylit, never where the brass day-arc sits on the plate.)
    ///
    /// Each numeral knows whether its hour is DAYLIT: numeral h IS
    /// the Sun at hour angle H — above the horizon when |H| < the
    /// sunset hour angle at the Sun's current declination. Polar
    /// seasons degrade gracefully: no sunset → all day, no sunrise →
    /// all night.
    @MainActor
    func dialNumerals()
        -> [(id: Int, text: String, position: CGPoint, rotation: Angle, isDay: Bool)] {
        let r = numeralRadius
        let sunVec   = SIMD3<Double>.eclipticPoint(lambda: sunLambda)
        let sunDec   = Angle.radians(asin(max(-1, min(1, sunVec.z))))
        let hSet     = Self.sunsetHourAngle(declination: sunDec, latitude: latitude)
        let polarDay = -tan(latitude.radians) * tan(sunDec.radians) < -1
        // The civil anchor: the Sun's hour angle now (H = LST − RA,
        // ringPoint's own convention) against the wall clock now.
        let sunHA    = lst.radians - atan2(sunVec.y, sunVec.x)
        let comps    = civilCalendar.dateComponents([.hour, .minute, .second],
                                                       from: date)
        let civilNow = Double(comps.hour ?? 12) + Double(comps.minute ?? 0) / 60
                     + Double(comps.second ?? 0) / 3600
        var out: [(Int, String, CGPoint, Angle, Bool)] = []
        for h in 0..<24 {
            let H = sunHA + (Double(h) - civilNow) / 24 * 2 * .pi
            guard let onRing = ringPoint(hourAngle: H, declination: romanDialDec)
            else { continue }
            let dx  = onRing.x - center.x, dy = onRing.y - center.y
            let len = max(hypot(dx, dy), 0.0001)
            let p   = CGPoint(x: center.x + dx / len * r,
                              y: center.y + dy / len * r)
            let rot = Angle.radians(atan2(Double(dy), Double(dx)) + .pi / 2)
            let Hn  = atan2(sin(H), cos(H))
            let day = hSet.map { abs(Hn) < $0 } ?? polarDay
            out.append((h, Self.romanTexts[h % 12], p, rot, day))
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

    /// Where the JWST sits on the face, if we know.
    @MainActor var jwstPoint: CGPoint? {
        jwst.flatMap { camera.screen(equatorial: $0) }
    }

    @MainActor var moonPoint: CGPoint? {
        let (vec, _, _) = MoonPosition.vector(for: date, siderealOffset: camera.sidereal)
        return camera.screen(rotatedEquatorial: vec)
    }

    /// The Sun's hand — from the axle THROUGH the badge point, tip
    /// landing on the Roman dial, Prague's gesture: badge, hand and
    /// numeral read as one line. THIS is how the clock tells time.
    /// `badgeClearance` BREAKS the arm around the badge itself: the
    /// clear-mode orb is translucent glass, and an arm running under
    /// it reads as a crack through the Sun. Two subpaths, one gap.
    @MainActor
    func sunHandPath(badgeClearance: CGFloat = 0) -> Path? {
        guard let p = sunPoint else { return nil }
        let dx  = p.x - center.x, dy = p.y - center.y
        let d   = max(hypot(dx, dy), 0.0001)
        let ux  = dx / d, uy = dy / d
        let tip = radiusForDeclination(romanDialDec)
        func along(_ r: CGFloat) -> CGPoint {
            CGPoint(x: center.x + ux * r, y: center.y + uy * r)
        }
        var hand = Path()
        hand.move(to: center)
        hand.addLine(to: along(min(max(d - badgeClearance, 0), tip)))
        if d + badgeClearance < tip {
            hand.move(to:    along(d + badgeClearance))
            hand.addLine(to: along(tip))
        }
        return hand
    }

    /// The little hand at the Sun arm's tip — Prague's golden pointer:
    /// a slim leaf riding the arm's last stretch, its apex reaching
    /// past the dial circle toward the numerals so the eye lands on
    /// the hour. ▼ TWEAK the pointer's cut here ▼
    @MainActor
    func sunHandTipPath() -> Path? {
        guard let p = sunPoint else { return nil }
        let dx  = p.x - center.x, dy = p.y - center.y
        let len = max(hypot(dx, dy), 0.0001)
        let ux  = dx / len, uy = dy / len            // outward
        let radius  = radiusForDeclination(romanDialDec)
        let apexAt  = radius + 5 * ui
        let baseAt  = radius - 9 * ui
        let halfW   = 2.6 * ui
        var tip = Path()
        tip.move(to:    CGPoint(x: center.x + ux * apexAt,
                                y: center.y + uy * apexAt))
        tip.addLine(to: CGPoint(x: center.x + ux * baseAt - uy * halfW,
                                y: center.y + uy * baseAt + ux * halfW))
        tip.addLine(to: CGPoint(x: center.x + ux * baseAt + uy * halfW,
                                y: center.y + uy * baseAt - ux * halfW))
        tip.closeSubpath()
        return tip
    }

    // MARK: Glass instrument (2.0)
    // The parts the glass face adds: altitude FIELDS as exact circles, the
    // rete fused into one piece, and every hand as a filled blade so it
    // can take glass.

    /// The rings of hours the glass face can wear.
    enum NumeralRing {
        /// The glass crown — a band whose outer edge is the scalloped
        /// squircle — carrying the Roman numerals, each its own glass.
        case crown
        /// The Roman numerals alone, in glass round the plate's edge.
        case roman
        /// Arabic even hours along the widget's edge, Contour-style; the
        /// plate fills the widget.
        case contour
    }

    /// Radius of the plate — the fields' clip, inside the crown.
    var plateRadius: CGFloat { radiusForDeclination(romanDialDec) + 3 * ui }

    /// ρ of the outer tropic in projection units — 2·tan(45° + ε/2),
    /// the same magnitude in either hemisphere.
    private static let tropicRho = 2 * tan(.pi / 4 + AstroConstants.tropicCancer.radians / 2)

    /// The Roman numerals' size on the glass face. ▼ TWEAK ▼
    static func glassNumeralSize(ui: CGFloat, type: CGFloat) -> CGFloat {
        (ui >= 0.7 ? 19 : 13) * type
    }

    /// Where the numerals' feet stand past the plate's edge, × ui — inside
    /// the outer tropic's glass ring, so they fuse with it. ▼ TWEAK ▼
    private static let plateNumeralGap: CGFloat = 0.2

    /// The outer tropic's ring and the Roman numerals standing on it, fused
    /// into one piece of glass.
    @MainActor
    func numeralCrownPath() -> Path {
        let ring = plateRingPaths().last ?? Path()
        return numeralGlassPaths()
            .reduce(ring) { $0.union($1.path) }
            .normalized(eoFill: false)
    }

    /// The glass plate's edge: the outer tropic, as on the original.
    var plateEdgeRadius: CGFloat { camera.scale * CGFloat(Self.tropicRho) }

    /// Where the plate's light reaches: the outer tropic under the Roman
    /// numerals, inside the crown's band, or the whole widget under the
    /// Contour ring.
    @MainActor
    func plateFillPath() -> Path {
        switch numeralRing {
        case .roman:   return circle(center, plateEdgeRadius)
        case .crown:   return plateDiscPath()
        case .contour: return Path(CGRect(origin: .zero, size: camera.size))
        }
    }

    /// How far a hand reaches along `u`: just past the plate's edge
    /// toward its numeral, touching the crown, or — on the Contour ring —
    /// to the numeral it points at. ▼ TWEAK ▼
    @MainActor
    func handReach(toward u: CGVector) -> CGFloat {
        switch numeralRing {
        case .roman:   return plateEdgeRadius - (0.8 * ui + 0.3) - 3.5 * ui   // short of the ring, a breath of gap
        case .crown:   return plateRadius + 3 * ui
        case .contour: return contourReach(toward: u)
        }
    }

    /// The Contour hand's reach: to just short of the numeral it points
    /// at — the track's distance in that direction, less that numeral's
    /// depth (it swells near now) and a breath of gap. ▼ TWEAK the gap ▼
    @MainActor
    private func contourReach(toward u: CGVector) -> CGFloat {
        let track   = contourTrack
        let station = track.arcLength(towards: u, from: center, samples: track.samples(count: 720))
        let edge    = track.point(at: station)
        let toEdge  = hypot(edge.point.x - center.x, edge.point.y - center.y)
        // The numeral's depth runs along the track's normal, not the ray.
        let slant   = max(-(u.dx * edge.inward.dx + u.dy * edge.inward.dy), 0.5)
        let depth   = contourDepth(emphasis: emphasisOfNumeral(toward: u))
        return toEdge - depth / slant - 3 * ui
    }

    /// The emphasis of the numeral nearest a direction from the axle.
    @MainActor
    private func emphasisOfNumeral(toward u: CGVector) -> Double {
        let target = atan2(u.dy, u.dx)
        let civil  = civilHourNow
        let nearest = contourDialNumerals().min { a, b in
            func gap(_ p: CGPoint) -> CGFloat {
                let d = atan2(p.y - center.y, p.x - center.x) - target
                return abs(atan2(sin(d), cos(d)))
            }
            return gap(a.position) < gap(b.position)
        }
        return nearest.map { contourEmphasis(hour: $0.id, now: civil) } ?? 0
    }


    /// Radius of the axle — the Earth, seen from above the pole.
    var hubRadius: CGFloat { 9 * ui }

    /// The four altitude circles, largest first: 0°, −6°, −12°, −18°.
    /// Each circle holds the sky BELOW its altitude (the night side sits
    /// inside, Prague's black disc), so painted in this order over a day
    /// plate they step it civil → nautical → astronomical → night.
    @MainActor
    func altitudeFields() -> [(altitude: Angle, path: Path)] {
        [Angle.zero, .degrees(-6), .degrees(-12), .degrees(-18)].compactMap { alt in
            guard let c = almucantarCircle(altitude: alt) else { return nil }
            return (alt, circle(c.centre, c.radius))
        }
    }

    /// The rete as ONE piece of glass: the zodiac band, the four spokes of
    /// its cross and the hub, fused into a single outline. Every junction
    /// is swept by a fillet, so the arms flow into the band and out of the
    /// hub instead of ending under them.
    ///
    /// `withStarHand`: the λ 0° spoke runs on through the band to the
    /// plate's edge. It points at the first point of Aries, so its angle
    /// IS sidereal time — the star hand, cast in the rete itself, with a
    /// star badge fused at its tip.
    /// `carvesGlyphs`: the sign glyphs are cut out of the band — holes,
    /// not marks laid over it.
    /// ▼ TWEAK the fillets and spoke weight here ▼
    @MainActor
    func reteGlassPath(withStarHand: Bool, carvesGlyphs: Bool) -> Path {
        guard let rims = zodiacRims() else { return Path() }
        let bandFillet: CGFloat = 7 * ui
        let hubFillet:  CGFloat = 4 * ui

        var rete = circle(rims.outer.centre, rims.outer.radius)
            .subtracting(circle(rims.inner.centre, rims.inner.radius))
        rete     = rete.union(circle(center, hubRadius))
        for spoke in reteSpokes(innerRim: rims.inner.radius, ringCentre: rims.inner.centre) {
            rete = rete.union(spoke.bar)
            for side in spoke.sides {
                if let web = filletWeb(along: side, circleCentre: rims.inner.centre,
                                       radius: rims.inner.radius,
                                       fillet: bandFillet, insideCircle: true,
                                       depth: bandSink) {
                    rete = rete.union(web)
                }
                if let web = filletWeb(along: side, circleCentre: center, radius: hubRadius,
                                       fillet: hubFillet, insideCircle: false,
                                       depth: hubRadius / 2) {
                    rete = rete.union(web)
                }
            }
        }
        if withStarHand, let star = starArm(outerRim: rims.outer.radius, ringCentre: rims.outer.centre) {
            rete = rete.union(star.bar)
            for side in star.sides {
                if let web = filletWeb(along: side, circleCentre: rims.outer.centre,
                                       radius: rims.outer.radius,
                                       fillet: bandFillet, insideCircle: false,
                                       depth: bandSink) {
                    rete = rete.union(web)
                }
            }
        }
        if withStarHand, let star = starBadgePath() {
            rete = rete.union(star)
        }
        if carvesGlyphs {
            let glyphs = zodiacGlyphPaths().reduce(Path()) { $0.union($1) }
            rete = rete.subtracting(glyphs)
        }
        return rete.subtracting(axleHole).normalized(eoFill: false)
    }

    // MARK: Axle and badges (2.0)

    /// The axle is a HOLE, not a pin: the plate shows through every layer
    /// at the centre, like the hub of the iOS Clock icon. ▼ TWEAK ▼
    var axleHoleRadius: CGFloat { 2.2 * ui }
    var axleHole: Path { circle(center, axleHoleRadius) }

    /// The collars the hands turn on, nested inside the rete's hub: the
    /// lower hand's collar is the wider, so each one shows round the next,
    /// like stacked washers. ▼ TWEAK ▼
    var moonCollarRadius: CGFloat { 6.4 * ui }
    var sunCollarRadius:  CGFloat { 4.6 * ui }

    /// The badges, across — the app's POI sizes in proportion. ▼ TWEAK ▼
    var sunBadgeSize:  CGFloat { 20 * ui }
    var moonBadgeSize: CGFloat { 15 * ui }
    var starBadgeSize: CGFloat { 12 * ui }

    /// A pentagon squircle `size` across, centred on `p` — the app's badge
    /// for the Sun and every star.
    private func pentagonBadge(at p: CGPoint, size: CGFloat) -> Path {
        Squircle(corners: 5, bulge: 5)
            .path(in: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size))
    }

    /// The star badge at the tip of the star hand, toward the first point
    /// of Aries — Prague's star, on the sidereal hand.
    @MainActor
    private func starBadgePath() -> Path? {
        guard let aries = camera.screen(equatorial: .eclipticPoint(lambda: .zero)) else { return nil }
        let u = unitVector(to: aries)
        return pentagonBadge(at: along(u, handReach(toward: u) - starBadgeSize / 2),
                             size: starBadgeSize)
    }

    /// The Moon's lit part, to lay over its badge in frosted glass: the
    /// real phase, its bright limb turned toward the Sun on the face.
    @MainActor
    func moonLitPath() -> Path? {
        guard let p = moonPoint, let sun = sunPoint else { return nil }
        let phase = MoonPosition.phase(for: date, latitude: latitude)
        guard !phase.isNew else { return nil }
        // Lit on the +x side, then turned to face the Sun.
        let shape = MoonPhaseShape(phase: LunarPhase(illuminatedFraction: phase.illuminatedFraction,
                                                     isWaxing: true, southernView: false))
        let d     = moonBadgeSize - 2.4 * ui            // a rim of the dark disc shows round it
        let place = CGAffineTransform(translationX: p.x, y: p.y)
            .rotated(by: atan2(sun.y - p.y, sun.x - p.x))
        return shape.path(in: CGRect(x: -d / 2, y: -d / 2, width: d, height: d)).applying(place)
    }

    /// How far an arm sinks into the band past the rim it joins — enough
    /// for a seamless union, never past the band's narrowest width.
    private var bandSink: CGFloat { 3 * ui }

    // MARK: Zodiac band (2.0)
    // The band as Prague draws it — by the projection. Its rims are the
    // two circles of ecliptic LATITUDE ±`zodiacHalfWidth` (true circles,
    // so off-centre and wide on the far side); each sign's divider is its
    // line of constant longitude between them; each glyph is warped into
    // its cell point by point through the same projection.

    /// Half-width of the band in ecliptic latitude. ▼ TWEAK ▼
    static let zodiacHalfWidth: Angle = .degrees(5)

    /// How much of its cell's height a glyph fills. ▼ TWEAK ▼
    static let zodiacGlyphFill: Double = 0.78

    typealias RimCircle = (centre: CGPoint, radius: CGFloat)

    /// The band's two rims, as exact circles.
    @MainActor
    func zodiacRims() -> (inner: RimCircle, outer: RimCircle)? {
        func rim(_ beta: Angle) -> RimCircle? {
            guard let a = screen(eclipticLongitude: .degrees(0),   latitude: beta),
                  let b = screen(eclipticLongitude: .degrees(120), latitude: beta),
                  let c = screen(eclipticLongitude: .degrees(240), latitude: beta)
            else { return nil }
            return Self.circle(through: a, b, c)
        }
        guard let north = rim(Self.zodiacHalfWidth),
              let south = rim(.radians(-Self.zodiacHalfWidth.radians)) else { return nil }
        return north.radius < south.radius ? (north, south) : (south, north)
    }

    /// Where the cross's arms meet the band — the equinoxes and solstices.
    static let reteArmLongitudes: [Double] = [0, 90, 180, 270]

    /// The Roman numerals as glass: each hour's numeral outlined in the
    /// dial's serif, centred on its ring point, feet to the centre.
    /// `isDay` lets the face frost the daylit hours.
    @MainActor
    func numeralGlassPaths() -> [(path: Path, isDay: Bool)] {
        // ▼ TWEAK the numerals' size ▼
        let size = Self.glassNumeralSize(ui: ui, type: type)
        return dialNumerals().compactMap { numeral in
            guard let outline = Self.romanOutlines[numeral.text] else { return nil }
            let box   = outline.boundingRect
            let place = CGAffineTransform(translationX: numeral.position.x, y: numeral.position.y)
                .rotated(by: numeral.rotation.radians)
                .scaledBy(x: size / 100, y: -size / 100)        // CoreText is y-up
                .translatedBy(x: -box.midX, y: -box.midY)
            return (outline.applying(place), numeral.isDay)
        }
    }

    // MARK: Contour numerals (2.0)
    // The hours laid along the widget's edge the way the Watch's Contour
    // face lays its digits: each numeral sits where its hour's direction
    // from the axle meets a rounded-rectangle track, and is STRETCHED to
    // fill its slot — along the track to its neighbours, inward to its
    // depth. The hour that has begun is the deepest and heaviest; the
    // hours just gone taper away behind it; the hours to come rest thin
    // until the hand reaches them.
    //
    // ORIENTATION is Contour's too, and it is decided by shape, not by
    // place: a numeral is never upside down — it either STANDS upright or
    // LIES on its side (a quarter turn), whichever fits its slot better
    // once SF Pro's width axis has done what it can (see `contourCut`). Slots on the top and bottom edges are long and
    // shallow, so a tall single digit lies down there and stands up on
    // the sides; a wide "12" stands at the top; a narrow "11" lies like a
    // single digit. A lying numeral's top points away from the face's
    // vertical centre line, so the two halves mirror.

    /// One numeral, stretched into the track.
    struct ContourNumeral {
        let path:     Path
        let isDay:    Bool
        /// 1 for the hour that has begun, tapering to 0 along the tail.
        let emphasis: Double
    }

    /// ▼ TWEAK the Contour track here ▼
    /// Gap between the widget's edge and the numerals' tops.
    var contourMargin:       CGFloat { 5 * ui + 1 }
    /// Corner radius of the track — at least the deepest numeral, or the
    /// corners would fold the glyphs over themselves.
    var contourCornerRadius: CGFloat { contourDepth(emphasis: 1) + 4 * ui }
    /// How much of its slot a numeral fills along the track.
    static let contourSlotFill:  CGFloat = 0.92
    /// Which hours carry a numeral: every `contourHourStep`-th — 2 gives
    /// twelve (2, 4 … 24), each with twice the room of a full ring.
    static let contourHourStep:  Int     = 2
    /// How many hours the tail trails behind the current one.
    static let contourTailHours: Double  = 8
    /// How much a numeral prefers SF's standard width when two cuts both
    /// fit — 0 lets the width axis roam freely.
    static let contourWidthPreference: CGFloat = 0.6
    /// What lying costs over standing: a numeral only turns on its side
    /// when standing clearly fits worse — upright reads without a tilt.
    static let contourLyingPenalty:    CGFloat = 0.45
    /// How far a numeral may be stretched along the track past its own
    /// proportions. Beyond this it keeps its shape and leaves its slot
    /// part-empty — a lying "1" stays a "1", and a corner numeral no
    /// longer wraps all the way round the bend.
    static let contourMaxStretch: CGFloat = 2.5

    /// Depth of a numeral into the widget, from its emphasis.
    func contourDepth(emphasis e: Double) -> CGFloat {
        let base = max(9,  12 * ui)
        let peak = max(20, 34 * ui)
        return base + (peak - base) * CGFloat(e)
    }

    /// The track itself.
    var contourTrack: OrlojContour {
        OrlojContour(rect:   CGRect(origin: .zero, size: camera.size)
                                 .insetBy(dx: contourMargin, dy: contourMargin),
                     radius: contourCornerRadius)
    }

    @MainActor
    func contourNumerals() -> [ContourNumeral] {
        let track    = contourTrack
        let samples  = track.samples(count: 1440)
        let numerals = contourDialNumerals()
        let civilNow = civilHourNow
        // Where each hour's direction meets the track.
        let stations = numerals.map { numeral in
            track.arcLength(towards: CGVector(dx: numeral.position.x - center.x,
                                              dy: numeral.position.y - center.y),
                            from: center, samples: samples)
        }
        return numerals.indices.compactMap { i in
            let numeral  = numerals[i]
            let emphasis = contourEmphasis(hour: numeral.id, now: civilNow)
            // The numeral's slot: halfway to each neighbour along the track.
            let previous = stations[(i + numerals.count - 1) % numerals.count]
            let next     = stations[(i + 1) % numerals.count]
            let slot     = (track.forward(from: previous, to: stations[i])
                          + track.forward(from: stations[i], to: next)) / 2
            let fill     = slot * Self.contourSlotFill
            let depth    = contourDepth(emphasis: emphasis)
            guard let cut = balancedCut(Self.stickOnes(Self.arabicText(hour: numeral.id)),
                                        stroke:  numeralStroke(emphasis: emphasis),
                                        nominal: nominalWeight(emphasis: emphasis),
                                        at: stations[i], on: track, fill: fill, depth: depth)
            else { return nil }
            let path     = track.stretch(cut.glyph.path,
                                         box:   cut.glyph.box,
                                         at:    stations[i],
                                         width: cut.along,
                                         depth: depth,
                                         up:    cut.up)
            return ContourNumeral(path: path, isDay: numeral.isDay, emphasis: emphasis)
        }
    }

    /// A numeral cut so its strokes come out `stroke` points thick on
    /// screen, whatever its orientation or slot: a lying numeral runs its
    /// height along the track and is set far larger than a standing one,
    /// so the same `wght` would read heavier.
    ///
    /// Orientation is a matter of SHAPE, so it's settled once, at the
    /// `nominal` weight. Within it the width is fitted, the scale measured,
    /// the weight solved for the stroke — and round again, since the weight
    /// nudges the fit.
    @MainActor
    private func balancedCut(_ text: String, stroke: CGFloat, nominal: Double,
                             at station: CGFloat, on track: OrlojContour,
                             fill: CGFloat, depth: CGFloat)
        -> (glyph: NumeralGlyph, up: CGVector, along: CGFloat)? {
        guard let settled = contourCut(text, weight: nominal, at: station, on: track,
                                       along: fill, depth: depth)
        else { return nil }
        var weight = nominal
        var result: (glyph: NumeralGlyph, up: CGVector, along: CGFloat)?
        for _ in 0..<3 {
            guard let cut = contourCut(text, weight: weight, at: station, on: track,
                                       along: fill, depth: depth, only: settled.up)
            else { return result }
            // Whatever the width axis couldn't absorb is stretched, up to the cap.
            let heightAlong = track.runsAlong(cut.up, at: station)
            let box         = cut.glyph.box
            let natural     = heightAlong ? box.height / box.width : box.width / box.height
            let along       = min(fill, depth * natural * Self.contourMaxStretch)
            result          = (cut.glyph, cut.up, along)
            // Points per font unit, across and up the glyph.
            let scaleX      = (heightAlong ? depth : along) / box.width
            let scaleY      = (heightAlong ? along : depth) / box.height
            let scale       = sqrt(scaleX * scaleY)
            weight          = Self.weight(forStem: stroke / scale, width: cut.width)
        }
        return result
    }

    /// How a numeral is cut and set in its slot: which way its top points
    /// on screen — standing, or lying with its top away from the vertical
    /// centre line — and at which SF Pro width. Each orientation gets the
    /// width whose ink best matches the slot; the one left with less
    /// stretch wins, and between two that both fit, the one nearer SF's
    /// standard width.
    @MainActor
    private func contourCut(_ text: String, weight: Double, at station: CGFloat,
                            on track: OrlojContour, along: CGFloat, depth: CGFloat,
                            only fixed: CGVector? = nil)
        -> (glyph: NumeralGlyph, up: CGVector, width: Double)? {
        let edge     = track.point(at: station).point
        let standing = CGVector(dx: 0, dy: -1)
        let lying    = CGVector(dx: edge.x >= center.x ? 1 : -1, dy: 0)
        let cuts = (fixed.map { [$0] } ?? [standing, lying]).compactMap {
            up -> (glyph: NumeralGlyph, up: CGVector, width: Double, cost: CGFloat)? in
            // When the glyph's height runs along the track, its ink width runs across it.
            let target = track.runsAlong(up, at: station) ? depth / along : along / depth
            guard let fit = Self.fittedNumeral(text, weight: weight, aspect: target)
            else { return nil }
            let offStandard = abs(CGFloat(log(fit.width / 100)))
            let lyingCost   = up == standing ? 0 : Self.contourLyingPenalty
            return (fit.glyph, up, fit.width,
                    fit.miss + Self.contourWidthPreference * offStandard + lyingCost)
        }
        return cuts.min { $0.cost < $1.cost }.map { ($0.glyph, $0.up, $0.width) }
    }

    /// 1–24 once round the day: noon is 12, midnight 24.
    private static func arabicText(hour: Int) -> String {
        hour % 24 == 0 ? "24" : "\(hour % 24)"
    }

    /// The digit 1 drawn as a plain stick — SF's capital I, the same height
    /// and stem as the figures, without the flag that turns strange when a
    /// "1" is stretched or laid on its side.
    private static func stickOnes(_ text: String) -> String {
        text.replacingOccurrences(of: "1", with: "I")
    }

    /// The dial's hours that carry a Contour numeral.
    @MainActor
    func contourDialNumerals()
        -> [(id: Int, text: String, position: CGPoint, rotation: Angle, isDay: Bool)] {
        dialNumerals().filter { $0.id % Self.contourHourStep == 0 }
    }

    /// The wall clock as a fractional hour — the same clock `dialNumerals`
    /// phases the ring against.
    private var civilHourNow: Double {
        let c = civilCalendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
    }

    /// The Contour swell: full for the hour that has begun, tapering over
    /// `contourTailHours` behind it, nothing ahead.
    private func contourEmphasis(hour: Int, now: Double) -> Double {
        let step    = Self.contourHourStep
        let current = (Int(now.rounded(.down)) / step * step) % 24   // the numeral whose span has begun
        let behind  = Double(((current - hour) % 24 + 24) % 24)     // 0 = that numeral
        return pow(max(0, 1 - behind / Self.contourTailHours), 1.3)
    }

    /// The twelve sign glyphs, each warped into its cell: tops toward the
    /// band's outside, as on the original, swelling where the band does.
    @MainActor
    func zodiacGlyphPaths() -> [Path] {
        guard let rims = zodiacRims() else { return [] }
        let bandCentre = CGPoint(x: (rims.inner.centre.x + rims.outer.centre.x) / 2,
                                 y: (rims.inner.centre.y + rims.outer.centre.y) / 2)
        return ZodiacSign.zodiac.compactMap { sign in
            guard let outline = Self.zodiacOutlines[sign.index - 1] else { return nil }
            return warped(outline,
                          into:       .degrees(Double(sign.index - 1) * 30 + 15),
                          bandCentre: bandCentre)
        }
    }

    /// Maps a glyph outline (CoreText units, y up) into the cell centred on
    /// longitude `lc`: glyph height → ecliptic latitude, glyph width →
    /// longitude, keeping the glyph's aspect at the cell's centre. Every
    /// point goes through the projection, so the glyph bends with the band.
    @MainActor
    private func warped(_ glyph: Path, into lc: Angle, bandCentre: CGPoint) -> Path? {
        let b   = Self.zodiacHalfWidth.degrees * Self.zodiacGlyphFill
        let box = glyph.boundingRect
        guard box.width > 0, box.height > 0,
              let mid    = screen(eclipticLongitude: lc,                       latitude: .zero),
              let north  = screen(eclipticLongitude: lc,                       latitude: .degrees(b)),
              let south  = screen(eclipticLongitude: lc,                       latitude: .degrees(-b)),
              let ahead  = screen(eclipticLongitude: lc + .degrees(0.5),       latitude: .zero),
              let behind = screen(eclipticLongitude: lc - .degrees(0.5),       latitude: .zero)
        else { return nil }

        // Top of the glyph faces the band's outside.
        let northIsOut = distance(north, bandCentre) > distance(south, bandCentre)
        let betaSign   = northIsOut ? 1.0 : -1.0
        let top        = northIsOut ? north : south
        // Width from the cell's local scale, so the glyph keeps its aspect.
        let heightPts  = distance(north, south)
        let ptsPerDeg  = max(distance(ahead, behind), 0.0001)
        let lambdaSpan = min(Double(box.width / box.height * heightPts / ptsPerDeg), 30 * 0.85)
        // Glyph-right must sit clockwise of glyph-up, or it reads mirrored.
        let cross      = (ahead.x - mid.x) * (top.y - mid.y) - (ahead.y - mid.y) * (top.x - mid.x)
        let lambdaSign = cross < 0 ? 1.0 : -1.0

        func warp(_ p: CGPoint) -> CGPoint {
            let gx = Double((p.x - box.minX) / box.width) - 0.5
            let gy = Double((p.y - box.minY) / box.height) * 2 - 1
            return screen(eclipticLongitude: lc + .degrees(gx * lambdaSpan * lambdaSign),
                          latitude:          .degrees(gy * b * betaSign)) ?? mid
        }
        var out = Path()
        glyph.forEach { element in
            switch element {
            case .move(let to):                 out.move(to: warp(to))
            case .line(let to):                 out.addLine(to: warp(to))
            case .quadCurve(let to, let c):     out.addQuadCurve(to: warp(to), control: warp(c))
            case .curve(let to, let c1, let c2): out.addCurve(to: warp(to), control1: warp(c1),
                                                             control2: warp(c2))
            case .closeSubpath:                 out.closeSubpath()
            }
        }
        return out
    }

    /// A point at ecliptic longitude λ and latitude β, on screen.
    @MainActor
    private func screen(eclipticLongitude lambda: Angle, latitude beta: Angle) -> CGPoint? {
        camera.screen(equatorial: Self.eclipticVector(lambda: lambda, beta: beta))
    }

    /// Ecliptic (λ, β) → equatorial unit vector, tilted by the obliquity
    /// exactly as `SIMD3.eclipticPoint` does for β = 0.
    private static func eclipticVector(lambda: Angle, beta: Angle) -> SIMD3<Double> {
        let e = AstroConstants.obliquity.radians
        let x = cos(beta.radians) * cos(lambda.radians)
        let y = cos(beta.radians) * sin(lambda.radians)
        let z = sin(beta.radians)
        return SIMD3(x, y * cos(e) - z * sin(e), y * sin(e) + z * cos(e))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// The sign glyphs' outlines from the system's own symbol font, built
    /// once per process. CoreText picks whichever font draws the sign
    /// (the variation selector asks for the text form, not the emoji).
    private static let zodiacOutlines: [Path?] = ZodiacSign.zodiac.map {
        glyphOutline($0.symbol, font: symbolFont)?.path
    }

    // MARK: Numeral type
    // SF Pro is a variable font: weight AND width are continuous axes. Each
    // numeral is cut at the weight its emphasis asks for and at the width
    // that fits its slot, so the stretch left over is small and the strokes
    // keep their even thickness — Contour's own trick.

    /// A numeral's outline at 100 pt and its box: the ink's bounds, padded
    /// across to `numeralMinAspect` for a numeral that's all stem.
    typealias NumeralGlyph = (path: Path, box: CGRect)

    /// ▼ TWEAK the numerals' type ▼
    /// Stroke thickness ON SCREEN (pt), at rest → the hour that has begun.
    /// The weight is solved per numeral to hit it (see `balancedCut`).
    var numeralStrokeRange: ClosedRange<CGFloat> { (0.9 * ui + 0.2)...(7 * ui) }
    /// The `wght` a numeral may be cut at — SF Pro's whole axis.
    static let numeralWeightLimits: ClosedRange<Double> = 1...1000
    /// The `wght` orientation is judged at, at rest → the hour that has
    /// begun: bold figures are wider, so emphasis may tip a numeral upright.
    static let numeralNominalWeights: ClosedRange<Double> = 120...900
    /// The narrowest a numeral's box may be (width ÷ height). A stick "1"
    /// is nothing but a stem; padded out to a digit's proportions it sits
    /// thin in its slot instead of being stretched into a slab.
    static let numeralMinAspect: CGFloat = 0.5
    /// `wdth`, compressed → expanded. SF's axis runs from 30, but its
    /// extra-compressed end turns unreadable at light weights.
    static let numeralWidthRange:  ClosedRange<Double> = 50...150

    func nominalWeight(emphasis e: Double) -> Double {
        let r = Self.numeralNominalWeights
        return r.lowerBound + (r.upperBound - r.lowerBound) * e
    }

    /// A numeral's stroke for its emphasis — geometric between the ends,
    /// so equal steps of emphasis read as equal steps of weight.
    func numeralStroke(emphasis e: Double) -> CGFloat {
        let r = numeralStrokeRange
        return r.lowerBound * pow(r.upperBound / r.lowerBound, CGFloat(e))
    }

    /// The `wght` whose stem is `stem` font units thick at this `wdth` —
    /// measured on SF's capital I, which is nothing but a stem. Bisected:
    /// stem thickness only grows with weight.
    @MainActor
    private static func weight(forStem stem: CGFloat, width: Double) -> Double {
        var low  = numeralWeightLimits.lowerBound
        var high = numeralWeightLimits.upperBound
        for _ in 0..<7 {
            let mid = (low + high) / 2
            guard let stick = numeralGlyph("I", weight: mid, width: width) else { return mid }
            if stick.path.boundingRect.width < stem { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }

    /// The SF width whose ink comes closest to `target` (ink width ÷
    /// height), and how far off it lands (log ratio). Ink width grows
    /// almost linearly along the axis, so the two ends pin it.
    @MainActor
    private static func fittedNumeral(_ text: String, weight: Double, aspect target: CGFloat)
        -> (glyph: NumeralGlyph, width: Double, miss: CGFloat)? {
        let range = numeralWidthRange
        guard let narrow = numeralGlyph(text, weight: weight, width: range.lowerBound),
              let wide   = numeralGlyph(text, weight: weight, width: range.upperBound)
        else { return nil }
        let narrowAspect = narrow.box.width / narrow.box.height
        let wideAspect   = wide.box.width   / wide.box.height
        let t            = min(max((target - narrowAspect) / max(wideAspect - narrowAspect, 0.0001), 0), 1)
        let width        = range.lowerBound + (range.upperBound - range.lowerBound) * Double(t)
        guard let glyph  = numeralGlyph(text, weight: weight, width: width) else { return nil }
        return (glyph, width, abs(log(target / (glyph.box.width / glyph.box.height))))
    }

    /// Outlines cut so far, keyed by text, weight and width (rounded, so
    /// the cache stays small across a timeline's renders).
    @MainActor private static var numeralCache: [String: NumeralGlyph] = [:]

    @MainActor
    private static func numeralGlyph(_ text: String, weight: Double, width: Double) -> NumeralGlyph? {
        let weight = (weight / 20).rounded() * 20
        let width  = (width  / 2).rounded()  * 2
        let key    = "\(text)|\(weight)|\(width)"
        if let hit = numeralCache[key] { return hit }
        guard let outline = glyphOutline(text, font: numeralFont(weight: weight, width: width))
        else { return nil }
        let ink   = outline.path.boundingRect
        let pad   = max(0, ink.height * numeralMinAspect - ink.width) / 2
        let glyph: NumeralGlyph = (outline.path, ink.insetBy(dx: -pad, dy: 0))
        numeralCache[key] = glyph
        return glyph
    }

    private static let numeralBase: CTFont = UIFont.systemFont(ofSize: 100) as CTFont

    /// SF Pro at an exact point on its weight and width axes.
    private static func numeralFont(weight: Double, width: Double) -> CTFont {
        let variations: [Int: Double] = [fourCC("wght"): weight, fourCC("wdth"): width]
        let descriptor = CTFontDescriptorCreateWithAttributes(
            [kCTFontVariationAttribute: variations] as CFDictionary)
        return CTFontCreateCopyWithAttributes(numeralBase, 100, nil, descriptor)
    }

    /// An OpenType axis tag as CoreText wants it.
    private static func fourCC(_ tag: String) -> Int {
        tag.utf8.reduce(0) { $0 << 8 | Int($1) }
    }

    /// The Roman numerals' outlines at 100 pt, in the serif-semibold voice
    /// the labels use, built once per process.
    private static let romanOutlines: [String: Path] = Dictionary(
        uniqueKeysWithValues: romanTexts.compactMap { text in
            glyphOutline(text, font: romanFont).map { (text, $0.path) }
        })

    private static let romanFont: CTFont = {
        var descriptor = UIFont.systemFont(ofSize: 100, weight: .semibold).fontDescriptor
        descriptor     = descriptor.withDesign(.serif) ?? descriptor
        return UIFont(descriptor: descriptor, size: 100) as CTFont
    }()

    private static let symbolFont: CTFont =
        CTFontCreateUIFontForLanguage(.system, 100, nil)
        ?? CTFontCreateWithName("Helvetica" as CFString, 100, nil)

    /// A string's outline at its font's size (CoreText units, y up) and
    /// its advance, whichever fonts CoreText falls back to for its characters.
    private static func glyphOutline(_ text: String, font: CTFont) -> (path: Path, advance: CGFloat)? {
        let attributed = NSAttributedString(string: text,
                                            attributes: [.init(kCTFontAttributeName as String): font])
        let line       = CTLineCreateWithAttributedString(attributed)
        let outline    = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let value = attributes[kCTFontAttributeName as String] else { continue }
            let runFont   = value as! CTFont
            let count     = CTRunGetGlyphCount(run)
            var glyphs    = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run,    CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            for (glyph, position) in zip(glyphs, positions) {
                guard let path = CTFontCreatePathForGlyph(runFont, glyph, nil) else { continue }
                outline.addPath(path, transform: CGAffineTransform(translationX: position.x,
                                                                   y: position.y))
            }
        }
        guard !outline.isEmpty else { return nil }
        return (Path(outline), CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
    }

    /// The star hand's arm: the λ 0° spoke continued from inside the band
    /// out to the crown, as wide as the spoke ends and round at the tip.
    /// Nil when the band already reaches the crown.
    @MainActor
    private func starArm(outerRim: CGFloat, ringCentre: CGPoint)
        -> (bar: Path, sides: [SpokeSide])? {
        guard let aries = camera.screen(equatorial: .eclipticPoint(lambda: .zero))
        else { return nil }
        let u     = unitVector(to: aries)
        let width = 3 * ui
        guard let reach = rayToCircle(from: center, toward: u,
                                      centre: ringCentre, radius: outerRim),
              handReach(toward: u) > reach + 6 * ui
        else { return nil }
        let start = along(u, reach - bandSink)
        let tip   = along(u, handReach(toward: u) - width / 2)
        let n     = CGVector(dx: -u.dy, dy: u.dx)
        let bar   = taperedBar(from: start, to: tip, startWidth: width, endWidth: width)
            .union(circle(tip, width / 2))
        let sides = [n, CGVector(dx: -n.dx, dy: -n.dy)].map { normal in
            SpokeSide(point:     CGPoint(x: start.x + normal.dx * width / 2,
                                         y: start.y + normal.dy * width / 2),
                      direction: u,
                      normal:    normal)
        }
        return (bar, sides)
    }

    /// One edge of a spoke: a point on it, its direction outward from the
    /// axle, and the normal pointing AWAY from the spoke's body.
    private struct SpokeSide {
        let point:     CGPoint
        let direction: CGVector
        let normal:    CGVector
    }

    /// The four spokes of the cross, at the equinoxes and solstices
    /// (λ 0°, 90°, 180°, 270°), each reaching into the band. The band is
    /// off-centre, so they come out in four different lengths.
    @MainActor
    private func reteSpokes(innerRim: CGFloat, ringCentre: CGPoint)
        -> [(bar: Path, sides: [SpokeSide])] {
        Self.reteArmLongitudes.compactMap { lambda in
            guard let p = camera.screen(equatorial: .eclipticPoint(lambda: .degrees(lambda)))
            else { return nil }
            let u = unitVector(to: p)
            guard let reach = rayToCircle(from: center, toward: u,
                                          centre: ringCentre, radius: innerRim)
            else { return nil }
            let start      = along(u, hubRadius * 0.6)
            let end        = along(u, reach + bandSink)
            let startWidth = 4 * ui
            let endWidth   = 3 * ui
            let n          = CGVector(dx: -u.dy, dy: u.dx)
            let sides = [1.0, -1.0].map { (sign: CGFloat) -> SpokeSide in
                let a = CGPoint(x: start.x + n.dx * sign * startWidth / 2,
                                y: start.y + n.dy * sign * startWidth / 2)
                let b = CGPoint(x: end.x + n.dx * sign * endWidth / 2,
                                y: end.y + n.dy * sign * endWidth / 2)
                let d = unit(CGVector(dx: b.x - a.x, dy: b.y - a.y))
                var normal = CGVector(dx: -d.dy, dy: d.dx)
                if normal.dx * n.dx * sign + normal.dy * n.dy * sign < 0 {
                    normal = CGVector(dx: -normal.dx, dy: -normal.dy)
                }
                return SpokeSide(point: a, direction: d, normal: normal)
            }
            return (taperedBar(from: start, to: end, startWidth: startWidth, endWidth: endWidth),
                    sides)
        }
    }

    /// The web of glass that fills the corner where a spoke edge meets a
    /// circle (the band's inner rim, or the hub), cut by a fillet circle
    /// tangent to both. `insideCircle`: the spoke runs inside the circle
    /// (the band's rim) rather than out of it (the hub). `depth` sinks the
    /// web's far edge into the solid it joins, so the union has no seam.
    private func filletWeb(along side: SpokeSide, circleCentre c: CGPoint, radius r: CGFloat,
                           fillet f: CGFloat, insideCircle: Bool, depth: CGFloat) -> Path? {
        let d = side.direction, n = side.normal
        // Fillet centre: on the edge's offset line, at r ∓ f from the circle's centre.
        let offset = CGPoint(x: side.point.x + n.dx * f, y: side.point.y + n.dy * f)
        guard let t = rayToCircle(from: offset, toward: d, centre: c,
                                  radius: insideCircle ? r - f : r + f),
              let s = rayToCircle(from: side.point, toward: d, centre: c, radius: r)
        else { return nil }
        let fc      = CGPoint(x: offset.x + d.dx * t, y: offset.y + d.dy * t)
        let radial  = unit(CGVector(dx: fc.x - c.x, dy: fc.y - c.y))
        let corner  = CGPoint(x: side.point.x + d.dx * s, y: side.point.y + d.dy * s)
        let toEdge  = CGPoint(x: fc.x - n.dx * f, y: fc.y - n.dy * f)          // tangent on the spoke
        let toRim   = CGPoint(x: c.x + radial.dx * r, y: c.y + radial.dy * r)  // tangent on the circle
        let sunk    = insideCircle ? r + depth : r - depth
        let cornerU = unit(CGVector(dx: corner.x - c.x, dy: corner.y - c.y))
        // The web's spoke-side edge runs INSIDE the spoke, not along its
        // edge: shapes that merely share an edge leave seams in the union.
        let overlap = 0.8 * ui
        func intoSpoke(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x - n.dx * overlap, y: p.y - n.dy * overlap)
        }
        var web = Path()
        web.addLines([intoSpoke(toEdge),
                      intoSpoke(corner),
                      CGPoint(x: c.x + cornerU.dx * sunk, y: c.y + cornerU.dy * sunk),
                      CGPoint(x: c.x + radial.dx  * sunk, y: c.y + radial.dy  * sunk),
                      toRim,
                      toEdge])
        web.closeSubpath()
        return web.subtracting(circle(fc, f))
    }

    /// The Sun's hand — a thin glass capsule turning on its collar at the
    /// axle, the Sun's pentagon badge fused on where the Sun stands.
    /// ▼ TWEAK the hands' proportions here ▼
    @MainActor
    func sunCapsulePath() -> Path? {
        guard let p = sunPoint else { return nil }
        let u = unitVector(to: p)
        return collaredHand(toward: u, length: handReach(toward: u),
                            width: 3.6 * ui, collar: sunCollarRadius)
            .union(pentagonBadge(at: p, size: sunBadgeSize))
            .subtracting(axleHole)
    }

    /// The Sun's colour, inset in its badge so a thin rim of clear glass
    /// shows round it (see `OrlojTintedGlass`). ▼ TWEAK the rim ▼
    @MainActor
    func sunBadgePath() -> Path? {
        sunPoint.map { pentagonBadge(at: $0, size: sunBadgeSize - 2 * 1.8 * ui) }
    }

    /// The Moon's hand — as long as the Sun's, slimmer, its round badge
    /// fused on where the Moon stands (the phase is laid over it apart,
    /// see `moonLitPath`).
    @MainActor
    func moonCapsulePath() -> Path? {
        guard let p = moonPoint else { return nil }
        let u = unitVector(to: p)
        return collaredHand(toward: u, length: handReach(toward: u),
                            width: 2.8 * ui, collar: moonCollarRadius)
            .union(circle(p, moonBadgeSize / 2))
            .subtracting(axleHole)
    }

    /// A hand that starts AT the axle: a capsule outward from a collar,
    /// instead of running through.
    private func collaredHand(toward u: CGVector, length: CGFloat,
                              width: CGFloat, collar: CGFloat) -> Path {
        capsuleHand(toward: u, length: length, tail: 0, width: width)
            .union(circle(center, collar))
    }

    // MARK: Glass helpers

    private func unit(_ v: CGVector) -> CGVector {
        let d = max(hypot(v.dx, v.dy), 0.0001)
        return CGVector(dx: v.dx / d, dy: v.dy / d)
    }

    private func unitVector(to p: CGPoint) -> CGVector {
        let dx = p.x - center.x, dy = p.y - center.y
        let d  = max(hypot(dx, dy), 0.0001)
        return CGVector(dx: dx / d, dy: dy / d)
    }

    private func along(_ u: CGVector, _ r: CGFloat) -> CGPoint {
        CGPoint(x: center.x + u.dx * r, y: center.y + u.dy * r)
    }

    /// Distance along a ray from `origin` to where it leaves a circle
    /// that contains the origin; nil if the ray misses.
    private func rayToCircle(from origin: CGPoint, toward u: CGVector,
                             centre: CGPoint, radius: CGFloat) -> CGFloat? {
        let ox   = origin.x - centre.x, oy = origin.y - centre.y
        let b    = u.dx * ox + u.dy * oy
        let disc = b * b - (ox * ox + oy * oy - radius * radius)
        guard disc >= 0 else { return nil }
        return -b + sqrt(disc)
    }

    /// A hand: a capsule along `u`, from `tail` behind the axle to `length`
    /// in front of it, round at both ends.
    private func capsuleHand(toward u: CGVector, length: CGFloat,
                             tail: CGFloat, width: CGFloat) -> Path {
        let rect  = CGRect(x: -tail, y: -width / 2, width: length + tail, height: width)
        let place = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: atan2(u.dy, u.dx))
        return Path(roundedRect: rect, cornerRadius: width / 2, style: .circular)
            .applying(place)
    }

    /// A straight bar tapering from `startWidth` to `endWidth`.
    private func taperedBar(from a: CGPoint, to b: CGPoint,
                            startWidth: CGFloat, endWidth: CGFloat) -> Path {
        let dx = b.x - a.x, dy = b.y - a.y
        let d  = max(hypot(dx, dy), 0.0001)
        let nx = -dy / d, ny = dx / d
        var path = Path()
        path.addLines([CGPoint(x: a.x + nx * startWidth / 2, y: a.y + ny * startWidth / 2),
                       CGPoint(x: b.x + nx * endWidth   / 2, y: b.y + ny * endWidth   / 2),
                       CGPoint(x: b.x - nx * endWidth   / 2, y: b.y - ny * endWidth   / 2),
                       CGPoint(x: a.x - nx * startWidth / 2, y: a.y - ny * startWidth / 2)])
        path.closeSubpath()
        return path
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

    /// Half the day arc of a parallel — `sunsetHourAngle`, run to π where
    /// it never sets and to 0 where it never rises.
    private static func daySemiArc(declination dec: Angle, latitude lat: Angle) -> Double {
        acos(min(max(-tan(lat.radians) * tan(dec.radians), -1), 1))
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

    private func circle(_ centre: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                              width: radius * 2, height: radius * 2))
    }
}

// MARK: - OrlojContour
// A rounded rectangle walked by arc length, clockwise from top-centre,
// with the inward normal at every point: the track the Contour numerals
// are laid along. Straight sides and circular corners, so the normal
// turns smoothly and a glyph bends round a corner instead of creasing.
struct OrlojContour {
    let rect:   CGRect
    let radius: CGFloat

    private var straightWidth:  CGFloat { max(rect.width  - 2 * radius, 0) }
    private var straightHeight: CGFloat { max(rect.height - 2 * radius, 0) }
    private var quarter:        CGFloat { .pi / 2 * radius }

    var length: CGFloat { 2 * (straightWidth + straightHeight) + 4 * quarter }

    /// The track's point and inward unit normal at arc length `s` (wraps).
    func point(at s: CGFloat) -> (point: CGPoint, inward: CGVector) {
        var t = s.truncatingRemainder(dividingBy: length)
        if t < 0 { t += length }
        let r = radius
        let segments: [CGFloat] = [straightWidth / 2, quarter, straightHeight, quarter,
                                   straightWidth,     quarter, straightHeight, quarter,
                                   straightWidth / 2]
        var index = 0
        while index < segments.count - 1, t > segments[index] {
            t     -= segments[index]
            index += 1
        }
        func corner(_ c: CGPoint, from start: CGFloat) -> (CGPoint, CGVector) {
            let phi = start + t / r
            return (CGPoint(x: c.x + r * cos(phi), y: c.y + r * sin(phi)),
                    CGVector(dx: -cos(phi), dy: -sin(phi)))
        }
        switch index {
        case 0:  return (CGPoint(x: rect.midX + t, y: rect.minY), CGVector(dx: 0, dy: 1))
        case 1:  return corner(CGPoint(x: rect.maxX - r, y: rect.minY + r), from: -.pi / 2)
        case 2:  return (CGPoint(x: rect.maxX, y: rect.minY + r + t), CGVector(dx: -1, dy: 0))
        case 3:  return corner(CGPoint(x: rect.maxX - r, y: rect.maxY - r), from: 0)
        case 4:  return (CGPoint(x: rect.maxX - r - t, y: rect.maxY), CGVector(dx: 0, dy: -1))
        case 5:  return corner(CGPoint(x: rect.minX + r, y: rect.maxY - r), from: .pi / 2)
        case 6:  return (CGPoint(x: rect.minX, y: rect.maxY - r - t), CGVector(dx: 1, dy: 0))
        case 7:  return corner(CGPoint(x: rect.minX + r, y: rect.minY + r), from: .pi)
        default: return (CGPoint(x: rect.minX + r + t, y: rect.minY), CGVector(dx: 0, dy: 1))
        }
    }

    /// Evenly spaced points round the track, for direction lookups.
    func samples(count: Int) -> [(s: CGFloat, point: CGPoint)] {
        (0..<count).map { i in
            let s = length * CGFloat(i) / CGFloat(count)
            return (s, point(at: s).point)
        }
    }

    /// Arc length where the ray from `origin` along `direction` meets the
    /// track (nearest sample by angle).
    func arcLength(towards direction: CGVector, from origin: CGPoint,
                   samples: [(s: CGFloat, point: CGPoint)]) -> CGFloat {
        let target = atan2(direction.dy, direction.dx)
        func gap(_ p: CGPoint) -> CGFloat {
            let a = atan2(p.y - origin.y, p.x - origin.x) - target
            return abs(atan2(sin(a), cos(a)))
        }
        return samples.min { gap($0.point) < gap($1.point) }?.s ?? 0
    }

    /// Distance going clockwise from `a` to `b`.
    func forward(from a: CGFloat, to b: CGFloat) -> CGFloat {
        let d = (b - a).truncatingRemainder(dividingBy: length)
        return d < 0 ? d + length : d
    }

    /// The track's tangent (clockwise) and outward normal at `s`.
    private func frame(at s: CGFloat) -> (along: CGVector, outward: CGVector) {
        let n = point(at: s).inward
        return (CGVector(dx: n.dy, dy: -n.dx), CGVector(dx: -n.dx, dy: -n.dy))
    }

    /// A screen direction snapped to the track's frame at `s`: ±1 along
    /// the track or ±1 outward, whichever it is nearer.
    private func snapped(_ v: CGVector, at s: CGFloat) -> (along: CGFloat, outward: CGFloat) {
        let f = frame(at: s)
        let a = v.dx * f.along.dx   + v.dy * f.along.dy
        let o = v.dx * f.outward.dx + v.dy * f.outward.dy
        return abs(a) >= abs(o) ? (a < 0 ? -1 : 1, 0) : (0, o < 0 ? -1 : 1)
    }

    /// Whether a glyph whose top points `up` on screen lies with its HEIGHT
    /// along the track at `s` (rather than across it).
    func runsAlong(_ up: CGVector, at s: CGFloat) -> Bool {
        snapped(up, at: s).along != 0
    }

    /// Stretches a glyph outline (CoreText units, y up) into a slot of the
    /// track centred on arc length `s`, its top pointing `up` on screen
    /// (snapped to the track's frame, so upright on a side means height
    /// along the track). `box` fills `width` along the track and `depth`
    /// inward. Every point is placed by the track, so the glyph bends
    /// round corners.
    func stretch(_ glyph: Path, box: CGRect, at s: CGFloat,
                 width: CGFloat, depth: CGFloat, up: CGVector) -> Path {
        guard box.width > 0, box.height > 0 else { return Path() }
        let top   = snapped(up, at: s)
        // The glyph's right is its up turned a quarter clockwise on screen.
        let right = snapped(CGVector(dx: -up.dy, dy: up.dx), at: s)
        func place(_ p: CGPoint) -> CGPoint {
            let gx    = (p.x - box.midX) / box.width        // −½ … ½, rightward
            let gy    = (p.y - box.midY) / box.height       // −½ … ½, upward
            let along = (gx * right.along   + gy * top.along)   * width
            let out   =  gx * right.outward + gy * top.outward  // −½ … ½
            let down  = (0.5 - out) * depth
            let edge  = point(at: s + along)
            return CGPoint(x: edge.point.x + edge.inward.dx * down,
                           y: edge.point.y + edge.inward.dy * down)
        }
        var out = Path()
        glyph.forEach { element in
            switch element {
            case .move(let to):                  out.move(to: place(to))
            case .line(let to):                  out.addLine(to: place(to))
            case .quadCurve(let to, let c):      out.addQuadCurve(to: place(to), control: place(c))
            case .curve(let to, let c1, let c2): out.addCurve(to: place(to), control1: place(c1),
                                                              control2: place(c2))
            case .closeSubpath:                  out.closeSubpath()
            }
        }
        return out
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
    /// Multiplies the band's LIT parts — sheen and rim light — leaving the
    /// tint slab and the casing alone, so the glass gets brighter without
    /// getting paler or losing its dark border.
    ///
    /// The band was the one element exempt from `brilliance`: every ink on
    /// the face runs through `ink()`, but GlassBand's sheen and rim were
    /// hardcoded, so the wrist's 1.9 gain never reached the glass and the
    /// crown stayed a widget-weight smudge on a screen a third the size.
    var glow:   Double = 1
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
            shape.fill(LinearGradient(colors: [.white.opacity(min(1, 0.14 * glow)),
                                               .white.opacity(min(1, 0.02 * glow))],
                                      startPoint: .top, endPoint: .bottom),
                       style: style)
            // Casing — the dark border every Ephoemerous badge wears
            // (poiTextBorderWidth, canvas-navy so it never goes light).
            shape.stroke(Artist.shared.canvasBackground.opacity(0.9),
                         lineWidth: Artist.shared.poiTextBorderWidth)
            // Rim light — bright top edge, fading out below. On the wrist
            // this edge is most of what says "crown": the scalloped rim is
            // the signature, so it carries the glow and gets weight with it.
            shape.stroke(LinearGradient(colors: [.white.opacity(min(1, 0.45 * glow)),
                                                 .white.opacity(min(1, 0.07 * glow))],
                                        startPoint: .top, endPoint: .bottom),
                         lineWidth: 0.8 * min(1.6, glow))
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
        let t = face.type

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

            // ── The memory layer, demoted to a whisper: you put
            // these here, you know where they are. Constellation
            // figures as hairline traces; remembered stars at tier-0
            // — the spectral pentagon at half size and half ink, no
            // casing, no glow. Sentiment, not signal.
            OrlojPath(source: face.favouriteConstellationsPath())
                .stroke(Self.silver.opacity(ink(0.3)),
                        style: .init(lineWidth: heft(0.8), lineCap: .round, lineJoin: .round))

            ForEach(face.favouriteStarMarks(), id: \.id) { mark in
                Squircle(corners: 5, bulge: Artist.shared.poiBadgeBulge)
                    .fill(markFill(top: mark.top, bottom: mark.bottom))
                    .frame(width: 5 * u, height: 5 * u)
                    .opacity(ink(0.65))
                    .position(mark.position)
            }


            // ── Fixed dial band (glass) — the real clock's black
            // outer ring, smoky so the sky reads through it. One
            // shadow per slab: GlassBand carries its own, no double.
            // Brighter on the wrist: less smoke in the slab (0.30 → 0.16)
            // so the sky doesn't drown it, and the sheen + rim finally run
            // through the same brilliance gain as every other ink.
            // ▼ TWEAK the crown's presence here ▼
            GlassBand(band: face.dialBandPath(),
                      tint: .black,
                      tintOpacity: face.wrist ? 0.16 : 0.30,
                      eoFill: true,
                      glow: face.wrist ? brilliance : 1,
                      lineArt: lineArt)

            // ── Plate filigree — the tropic circles. On the wrist they go:
            // on the wrist they're two more grey rings among the ecliptic,
            // the horizon and the plate's own edge, and the tympan's fields
            // already say where the plate begins and ends.
            if face.showsFiligree {
                ForEach(Array(face.platePaths().enumerated()), id: \.offset) { _, plate in
                    OrlojPath(source: plate.path)
                        .stroke(Self.silver.opacity(ink(0.85)), lineWidth: heft(plate.width))
                }
            }
            // (The −18° twilight hairline is retired — the tympan
            // fields' own edges bound AVRORA/CREPVSCVLVM now.)
            // Unequal hours — twelve of the face's circles, so they
            // earn their place only where there's room: fainter ink,
            // and gone entirely on the small family (u < 0.7), where
            // they read as fog.
            if u >= 0.7 {
                OrlojPath(source: face.unequalHoursPath())
                    .stroke(Self.silver.opacity(ink(0.35)), lineWidth: heft(0.5))
            }

            // Tympan region labels — the original's Latin, laid out
            // character by character ALONG their bands' curves, with
            // the app's dark casing so they hold up at a squint.
            ForEach(face.tympanLabelChars(), id: \.id) { glyph in
                Text(glyph.char)
                    .font(.system(size: max(3.5, 6.5 * t), weight: .medium, design: .serif))
                    .foregroundStyle(Self.silver.opacity(ink(0.8)))
                    .shadow(color: Artist.shared.canvasBackground.opacity(0.9),
                            radius: lineArt ? 0 : 1)
                    .rotationEffect(glyph.rotation)
                    .position(glyph.position)
            }

            // ── The crown carries NUMERALS ALONE, in the app's label
            // voice: OutlinedText with the real dark casing, crisp at
            // any zoom, squint-proof. Phased CIVIL — the hand reads
            // the wall clock (see `dialNumerals`) — in TWO METALS:
            // daylit hours brass, night hours silver, same volume,
            // different temperature — the crown echoes the tympan.
            // On the wrist only the Sun's own hour is worn (`sunHour`), and
            // with no neighbours to crowd it, it is drawn HALF AGAIN as
            // large — the ring's slot no longer caps the type.
            // ▼ TWEAK the lone numeral's size here ▼
            let numeralSize = face.wrist ? 14 * t : 9 * t
            ForEach(face.dialNumerals().filter {
                        !face.wrist || $0.id == face.sunHour
                    }, id: \.id) { numeral in
                Group {
                    if lineArt {
                        // Fill + casing both resolve to white and merge —
                        // the numerals turn into solid blocks. Plain
                        // glyphs; night dims where metal can't speak.
                        Text(numeral.text)
                            .font(.system(size: numeralSize, weight: .semibold,
                                          design: .serif))
                            .foregroundStyle(.white.opacity(numeral.isDay ? 1 : 0.65))
                    } else {
                        OutlinedText(text:      numeral.text,
                                     fill:      numeral.isDay ? Self.brass : Self.silver,
                                     stroke:    Artist.shared.canvasBackground,
                                     lineWidth: max(0.7, 1.2 * u),
                                     font:      Self.numeralFont(size: numeralSize))
                    }
                }
                .rotationEffect(numeral.rotation)
                .position(numeral.position)
            }

            // ── Rete: the zodiac band — smoky dark glass like the
            // original's black ring, sign dividers spanning rim to
            // rim, glyphs between the rims. RING DIET: the explicit
            // silver rim traces are retired — GlassBand's own casing
            // + rim light already edge the band, and three strokes
            // per edge was the fuzz. One shadow per slab, no double.
            GlassBand(band: face.zodiacBandPath(),
                      tint: .black, tintOpacity: 0.35, eoFill: true,
                      lineArt: lineArt)
            // Sign dividers — dropped on the wrist. The glyphs already
            // mark where each sign starts; the ticks only added a picket
            // fence around the one band the eye should be reading.
            if face.showsFiligree {
                OrlojPath(source: face.zodiacTicksPath())
                    .stroke(Self.silver.opacity(ink(0.6)), lineWidth: heft(0.8))
            }
            ForEach(face.zodiacGlyphs(), id: \.id) { glyph in
                Text(glyph.symbol)
                    .font(.system(size: 11 * t, weight: .bold))
                    .foregroundStyle(Self.silver)
                    .shadow(color: .black.opacity(0.9), radius: lineArt ? 0 : 1, y: lineArt ? 0 : 0.5)
                    .rotationEffect(glyph.rotation)
                    .position(glyph.position)
            }

            // ── The wanderers — the app's own planet badges (Jupiter's
            // bands, Saturn's rings, Mars's cap, Venus in phase), so the
            // clock speaks the sky's language. Laid out at size, never
            // scaled: a scale effect stretches the badge's bitmap soft.
            // ▼ TWEAK the planets' size on the face ▼
            ForEach(face.planetMarks(), id: \.id) { mark in
                POILabelView(category:   .planet(mark.planet),
                             text:       "",
                             labelStyle: .planetoids,
                             nameReveal: 0,
                             phase:      BadgePhase.of(.planet(mark.planet),
                                                       date: face.date, latitude: face.latitude),
                             sizeScale:  0.7 * max(0.55, u))
                    .position(mark.position)
            }
            // The JWST — the one craft slow enough for a face that steps
            // every quarter hour (~2° a day at L2). The others would be a
            // lie by the next beat.
            if let webb = face.jwstPoint {
                POILabelView(category:   .spacecraft(.jwst),
                             text:       "",
                             nameReveal: 0,
                             sizeScale:  0.7 * max(0.55, u))
                    .position(webb)
            }


            // ── The hand — ONE, the Sun's, SOLID brass running from
            // the axle THROUGH its badge to the Roman dial, tipped
            // with Prague's little golden pointer so badge, hand and
            // numeral read as one line. The only element loud enough
            // for a real shadow — it answers "what time is it";
            // everything else is scenery. The Moon keeps no arm: it
            // rides the ecliptic as a free body, so the face has one
            // unambiguous time-teller. Badges ride on top.
            // Under line art the badge is translucent glass and the
            // arm shows straight through it — a crack across the Sun
            // — so the arm BREAKS around it there: clearance = the
            // badge's visual radius (11pt of a 22pt orb, at the pin's
            // own scale) plus a breath. Full colour keeps the arm
            // whole; an opaque badge hides it already.
            if let hand = face.sunHandPath(
                badgeClearance: lineArt ? 14 * max(0.55, u) : 0) {
                handView(hand, tint: Self.brass, width: 2.0 * u)
            }
            if let tip = face.sunHandTipPath() {
                OrlojPath(source: tip)
                    .fill(lineArt ? AnyShapeStyle(Color.white.opacity(0.85))
                                  : AnyShapeStyle(Self.brass))
                    .overlay(OrlojPath(source: tip)
                        .stroke(markCasing, lineWidth: lineArt ? 0 : 1))
            }
            // The axle — a small brass hub grounding the hand.
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
                             sizeScale:  max(0.55, u))
                    .position(sun)
            }
            if let moon = face.moonPoint {
                POILabelView(category:   .moon,
                             text:       "",
                             labelStyle: .planetoids,
                             nameReveal: 0,
                             phase:      MoonPosition.phase(for: face.date,
                                                            latitude: face.latitude),
                             sizeScale:  max(0.55, u))
                    .position(moon)
            }
        }
        .scaleEffect(0.95)
        // A clock face doesn't reflow: the numerals and glyphs are fixed,
        // so the badges (which follow Text Size) must hold too, or the
        // bodies would swell against a dial that doesn't.
        .dynamicTypeSize(.large)
    }
}

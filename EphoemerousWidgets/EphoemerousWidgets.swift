import WidgetKit
import SwiftUI
import UIKit
import AppIntents
import LoreKit
import simd

// MARK: - SkyObjectWidgetIntent
// The widget's configuration: ONE parameter, the sky object to keep on
// the Home Screen. The picker comes for free from `SkyObjectQuery` —
// Sun, Moon, each planet, then everything the user has Remembered.
struct SkyObjectWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Sky Object"
    static let description = IntentDescription(
        "Keep a star, planet, the Sun or the Moon on your Home Screen."
    )

    @Parameter(title: "Object")
    var object: SkyObjectEntity?
}

// MARK: - Provider
struct SkyObjectProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> SkyObjectEntry {
        SkyObjectEntry(date: .now, captured: .now,
                       entity: SkyObjectEntity(.moon), origin: nil)
    }

    func snapshot(for configuration: SkyObjectWidgetIntent,
                  in context: Context) async -> SkyObjectEntry {
        await SkyObjectEntry(date: .now, captured: .now,
                             entity: configuration.object ?? SkyObjectEntity(.moon),
                             origin: FavouritesStore().observerOrigin())
    }

    func timeline(for configuration: SkyObjectWidgetIntent,
                  in context: Context) async -> Timeline<SkyObjectEntry> {
        // One entry per 5-minute freshness beat (the label steps Now →
        // 5 min ago → …, no live counter), each re-projecting the sky at
        // its own date so the map stays honest between provider runs.
        let entity   = configuration.object ?? SkyObjectEntity(.moon)
        let origin   = await FavouritesStore().observerOrigin()
        let captured = Date.now
        let entries  = stride(from: 0, through: 30, by: 5).map { m in
            SkyObjectEntry(date:     captured.addingTimeInterval(Double(m) * 60),
                           captured: captured,
                           entity:   entity,
                           origin:   origin)
        }
        return Timeline(entries: entries,
                        policy: .after(captured.addingTimeInterval(35 * 60)))
    }
}

struct SkyObjectEntry: TimelineEntry {
    /// The display beat this entry renders at (sky is projected for this).
    let date:     Date
    /// When the provider actually ran — the freshness anchor.
    let captured: Date
    let entity:   SkyObjectEntity
    /// Observer origin (degrees) the app last parked at — nil before the
    /// app has ever backgrounded; the map falls back to Greenwich.
    let origin:   (latDeg: Double, lonDeg: Double)?

    /// Bucketed freshness, Find My style — Now, then 5-minute steps to an
    /// hour, then hours, then days. Deterministic per entry; no timer.
    var freshnessLabel: String {
        let mins = Int(date.timeIntervalSince(captured) / 60)
        if mins < 5 { return String(localized: "Now") }
        if mins < 60 {
            return String(localized: "\((mins / 5) * 5) min ago")
        }
        let hours = mins / 60
        if hours < 24 {
            return String(localized: "\(hours) h ago")
        }
        return String(localized: "\(hours / 24) day ago")
    }
}

// MARK: - Pin geometry
// One source of truth for the promoted-pin layout so the CAMERA (which
// must land the object's projection on the dot) and the OVERLAY (badge,
// dot) agree to the pixel. Content margins are disabled on the widget,
// so canvas and overlay share the full-bleed coordinate space.
private enum Pin {
    /// Badge centre → dot centre drop, the promoted-pin lift.
//    static let lift: CGFloat = 24.0

    /// The precise-location dot — where the camera lands the object.
    /// Near the tile's midpoint (Find My plants its pin there), a touch
    /// trailing so the lifted badge reads top-trailing. ▼ TWEAK ▼
    static func dot(in size: CGSize, isLandscape: Bool) -> CGPoint {
        CGPoint(x: size.width * (isLandscape ? 0.77 : 0.68), y: size.height * (isLandscape ? 0.47 : 0.35))
    }

    /// Badge centre — lifted straight above the dot.
    static func badgeCentre(in size: CGSize, lift: CGFloat = 0.0, isLandscape: Bool) -> CGPoint {
        let d = dot(in: size, isLandscape: isLandscape)
        return CGPoint(x: d.x, y: d.y - lift)
    }
}

// MARK: - Sky snapshot
// The REAL sky at `date` from the observer's origin — the same
// stereographic pipeline the app renders with (`SkyCamera` +
// `Projection`, compiled into this target), drawn once into a
// widget-sized Canvas. The camera is offset so the object's projection
// lands exactly on the pin's precise-location dot.
// Internal (not private): the app's `SkyShareCard` renders the very same
// sky for the share postcard, so the two can never drift apart.
struct SkySnapshot {

    let camera: SkyCamera
    let date:   Date
    let isLandscape: Bool
    /// Where the pinned object lands on the tile. The widget uses the
    /// Find My pin dot; the share card centres it higher, above its
    /// footer. Bodies that would collide with it are dropped.
    let focusPoint: CGPoint
    /// Set when the PINNED object is a constellation — it has no badge
    /// or dot; instead its stick-figure is traced solid on the map.
    let pinnedConstellation: Constellation?
    /// The pinned object's direction, in the SAME sidereally-rotated
    /// frame the camera projects from — kept for the altitude/azimuth
    /// readout (large family only) so it isn't recomputed twice.
    private let pinnedVector: SIMD3<Double>?

    @MainActor
    init(entity: SkyObjectEntity, date: Date,
         origin: (latDeg: Double, lonDeg: Double)?, size: CGSize, isLandscape: Bool,
         focus: CGPoint? = nil) {
        self.date = date
        self.isLandscape = isLandscape
        if case .constellation(let c) = entity.skyObject {
            pinnedConstellation = c
        } else {
            pinnedConstellation = nil
        }

        let lat = Angle.degrees(origin?.latDeg ?? 51.48)   // Greenwich fallback
        let lon = Angle.degrees(origin?.lonDeg ?? 0)
        let viewpoint = Projection.Viewpoint(
            originVector: Angle.spherePoint(latitude: lat, longitude: lon),
            planeVector:  Angle.spherePoint(latitude: .radians(-lat.radians),
                                            longitude: lon + .radians(.pi)))
        // −GMST, not −LST: the viewpoint anchors are geographic globe
        // vectors, so longitude lives in the anchor and the sky spins by
        // GMST alone — same frame as the app (see localSiderealOffset).
        let sidereal = -Precession.gmstSiderealOffset(for: date)

        // ▼ TWEAK the postcard zoom here — screen pt per projection unit ▼
        let scale: CGFloat = 110

        // Offset the camera so the object projects ONTO THE PIN DOT —
        // screen() = size/2 + (p.x·s, −p.y·s) + offset, so solve for
        // offset with the dot as the wanted screen point. Objects that
        // fail to project (antipodal degeneracy) fall back to zenith-ish.
        let target = Self.vector(for: entity, date: date, sidereal: sidereal)
        pinnedVector = target
        let dot = focus ?? Pin.dot(in: size, isLandscape: isLandscape)
        focusPoint = dot
        var offset = CGSize.zero
        if let target, let p = Projection.project(target, viewpoint: viewpoint) {
            offset = CGSize(width:  dot.x - size.width  / 2 - p.x * scale,
                            height: dot.y - size.height / 2 + p.y * scale)
        }

        camera = SkyCamera(scale:     scale,
                           offset:    offset,
                           size:      size,
                           viewpoint: viewpoint,
                           sidereal:  sidereal)
    }

    /// "34° up · NE" — the pinned object's altitude above the horizon and
    /// compass bearing, derived straight from the projection vectors:
    /// `sin(altitude) = target · zenith`, and the horizon-plane residual
    /// resolves the bearing against the SAME (e1 = north, e2 = west)
    /// basis `skyPoint(azimuth:altitude:)` builds from. Nil when the
    /// object has no single direction (constellation) or fails to
    /// resolve.
    var altitudeAzimuthLabel: String? {
        guard let target = pinnedVector else { return nil }
        let zenith = camera.viewpoint.originVector
        let sinAlt = simd_dot(target, zenith)
        let altDeg = asin(max(-1, min(1, sinAlt))) * 180 / .pi

        let (e1, e2) = zenith.baseVectors()
        let residual = target - sinAlt * zenith
        let x = simd_dot(residual, e1)          // ∝ cos(alt)·cos(az)
        let y = simd_dot(residual, e2)          // ∝ −cos(alt)·sin(az)
        let azDeg = (atan2(-y, x) * 180 / .pi).truncatingRemainder(dividingBy: 360)
        let bearing = Self.compassPoints[Int(((azDeg < 0 ? azDeg + 360 : azDeg) / 22.5)
                                             .rounded()) % 16]

        let altText = altDeg >= 0
            ? String(localized: "\(Int(altDeg.rounded()))° up")
            : String(localized: "\(Int(-altDeg.rounded()))° below horizon")
        return "\(altText) · \(bearing)"
    }

    private static let compassPoints = [
        "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
        "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
    ]

    /// The object's position in the sidereally-rotated frame the camera
    /// projects from — same helpers the app's overlay layers use.
    @MainActor
    private static func vector(for entity: SkyObjectEntity, date: Date,
                               sidereal: Angle) -> SIMD3<Double>? {
        switch entity.skyObject {
        case .star(let s):
            return s.equatorialVector.sidereallyRotated(by: sidereal)
        case .sun:
            let lambda = SunPosition.eclipticLongitude(for: date)
            return SIMD3.eclipticPoint(lambda: lambda).sidereallyRotated(by: sidereal)
        case .moon:
            let (vec, _, _) = MoonPosition.vector(for: date, siderealOffset: sidereal)
            return vec
        case .planet(let p):
            return PlanetPosition.allVectors(for: date, siderealOffset: sidereal)
                .first { $0.0 == p }?.1
        case .constellation(let c):
            // The figure-star centroid — the same anchor the app labels
            // the constellation at — so the FIGURE parks on the pin spot.
            guard let anchor = ConstellationLines.shared.labelAnchors[c] else { return nil }
            return Precession.equatorialVector(ra: anchor.ra, dec: anchor.dec)
                .sidereallyRotated(by: sidereal)
        // The widget process carries no orbit data — and a pin that moves
        // four degrees a minute has no business on a postcard anyway.
        case .spacecraft, nil:
            return nil
        }
    }

    /// The solar-system bodies as (category, screen point, name) — the
    /// map furniture. The pinned object is excluded (it IS the pin), as
    /// is anything close enough to collide with the lifted badge.
    @MainActor
    func bodies(excluding pinned: String, in size: CGSize) -> [(POICategory, CGPoint, String)] {
        var out: [(POICategory, CGPoint, String)] = []
        let badge = focusPoint

        func admit(_ sc: CGPoint?) -> CGPoint? {
            guard let sc,
                  sc.x > 8, sc.x < size.width - 8,
                  sc.y > 8, sc.y < size.height - 8,
                  hypot(sc.x - badge.x, sc.y - badge.y) > 44 else { return nil }
            return sc
        }

        if pinned != "sun" {
            let lambda = SunPosition.eclipticLongitude(for: date)
            if let sc = admit(camera.screen(equatorial: .eclipticPoint(lambda: lambda))) {
                out.append((.sun, sc, SkyObject.sun.displayName))
            }
        }
        if pinned != "moon" {
            let (vec, _, _) = MoonPosition.vector(for: date, siderealOffset: camera.sidereal)
            if let sc = admit(camera.screen(rotatedEquatorial: vec)) {
                out.append((.moon, sc, SkyObject.moon.displayName))
            }
        }
        for (planet, vec, _, _) in PlanetPosition.allVectors(for: date,
                                                              siderealOffset: camera.sidereal)
        where pinned != "planet_\(planet.name)" {
            if let sc = admit(camera.screen(rotatedEquatorial: vec)) {
                out.append((.planet(planet), sc, planet.displayName))
            }
        }
        return out
    }

    /// Star field, constellation stick-figures + names, the dashed
    /// horizon — the postcard's cartography, all through the camera.
    /// `magnitudeLimit` lets the larger family show a denser field —
    /// there's room to breathe without the map turning to noise.
    /// Constellation names give way to anything in `avoid` (the marks the
    /// tile draws on top — bodies, the pin, the name block) and to each
    /// other.
    @MainActor
    func draw(in ctx: inout GraphicsContext, size: CGSize, magnitudeLimit: Double = 4.5,
              avoid: [CGRect] = []) {
        // The app's own field-star style (see `Artist+StarField`): grey ink,
        // colour reserved for the marks you can tap, named stars a step
        // above the nameless, the pentagon squircle, the glow.
        let a      = Artist.shared
        let zenith = camera.viewpoint.originVector
        // A tile is small and static — it needs a firmer field than the
        // live sky to read as stars, not haze. ▼ TWEAK the tile's field ▼
        let gain   = 1.3
        for star in StarDatabase.shared.workableStars where star.magnitude <= magnitudeLimit {
            guard let sc = camera.screen(equatorial: star.equatorialVector),
                  sc.x > -4, sc.x < size.width + 4,
                  sc.y > -4, sc.y < size.height + 4 else { continue }
            a.drawFieldStar(ctx,
                            at:           sc,
                            magnitude:    star.magnitude,
                            named:        star.properName != nil,
                            scale:        camera.scale,
                            gain:         gain,
                            aboveHorizon: simd_dot(star.equatorialVector.sidereallyRotated(by: camera.sidereal),
                                                   zenith) > 0)
        }

        // Constellation stick-figures — the app's quiet dotted grey; the
        // PINNED constellation is the hero and gets traced separately.
        let a_     = Artist.shared
        var sticks = Path()
        var hero   = Path()
        for (cons, segs) in ConstellationLines.shared.segments {
            for seg in segs {
                guard let a = camera.screen(equatorial: seg.a.equatorialVector),
                      let b = camera.screen(equatorial: seg.b.equatorialVector),
                      hypot(a.x - b.x, a.y - b.y) < size.width else { continue }
                let onTile = { (p: CGPoint) in
                    p.x > -20 && p.x < size.width + 20 &&
                    p.y > -20 && p.y < size.height + 20
                }
                guard onTile(a) || onTile(b) else { continue }
                // Stopping short of both stars, as on the app's sky.
                let gap = { (s: Star) in a_.fieldStarRadius(magnitude: s.magnitude, scale: camera.scale)
                                         + a_.figureGapMargin }
                guard let (p, q) = a_.figureSegment(from: a, to: b, gapA: gap(seg.a), gapB: gap(seg.b))
                else { continue }
                if cons == pinnedConstellation {
                    hero.move(to: p)
                    hero.addLine(to: q)
                } else {
                    sticks.move(to: p)
                    sticks.addLine(to: q)
                }
            }
        }
        ctx.stroke(sticks,
                   with: .color(.white.opacity(0.22)),        // ▼ TWEAK the figures' ink ▼
                   style: StrokeStyle(lineWidth: a_.figureLineWidth, lineCap: .round))
        // The hero figure: a SOLID trace, like a selected constellation
        // in the app — the line IS the promoted label here.
        ctx.stroke(hero,
                   with: .color(.white.opacity(0.75)),
                   style: StrokeStyle(lineWidth: 1.2,
                                      lineCap: .round, lineJoin: .round))

        // Constellation names at their figure centroids, in the app's
        // REGION voice — spaced caps, medium, haloed in the sky's colour —
        // sized down for the tile. Like the app's names they give way: to
        // the marks in `avoid`, and to each other (alphabetical, so the
        // same name wins every render). The pinned one is skipped: the
        // bottom-leading block names it.
        let fontSize: CGFloat = 8                      // ▼ TWEAK the tile's name size ▼
        // The app's spacing is set for caption2 (11 pt); keep its ratio.
        let tracking = a.regionTracking * fontSize / 11
        let font     = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        var placed   = avoid
        let tile     = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
        var names    = ctx
        names.addFilter(.shadow(color: a.canvasBackground, radius: a.regionHalo))
        for (cons, anchor) in ConstellationLines.shared.labelAnchors.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        where cons != pinnedConstellation {
            let vec = Precession.equatorialVector(ra: anchor.ra, dec: anchor.dec)
            guard let sc = camera.screen(equatorial: vec),
                  sc.x > 10, sc.x < size.width - 10,
                  sc.y > 10, sc.y < size.height - 10 else { continue }
            let text = cons.localizedName.uppercased()
            let w    = (text as NSString).size(withAttributes: [.font: font, .kern: tracking]).width
            let box  = CGRect(x: sc.x - w / 2, y: sc.y - font.lineHeight / 2,
                              width: w, height: font.lineHeight).insetBy(dx: -2, dy: -2)
            // The WHOLE name on the tile — a word cut by the edge reads
            // as broken — and clear of everything already placed.
            guard tile.contains(box),
                  !placed.contains(where: { $0.intersects(box) }) else { continue }
            placed.append(box)
            names.draw(Text(text)
                         .font(.system(size: fontSize, weight: a.regionWeight))
                         .tracking(tracking)
                         .foregroundStyle(.secondary),
                       at: sc)
        }

        // Horizon — the same dashed great circle the app draws, sampled
        // through the camera so it lands exactly where the app puts it.
        var horizon = Path()
        var started = false
        for i in 0 ... 96 {
            let q = camera.viewpoint.skyPoint(altitude: .zero,
                                              at: Double(i) / 96)
            guard let sc = camera.screen(rotatedEquatorial: q),
                  abs(sc.x) < 4000, abs(sc.y) < 4000 else { started = false; continue }
            if started { horizon.addLine(to: sc) } else { horizon.move(to: sc); started = true }
        }
        ctx.stroke(horizon,
                   with: .color(.white.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
    }
}

// MARK: - Entry view
// The Find My postcard: the live sky map fills the tile — stars,
// constellation figures + names, the horizon, and the other solar-system
// bodies as flat POI labels (the map look). The configured object is the
// PIN: its badge lifted above its precise-location dot near the tile's
// midpoint, the map offset so the object genuinely sits there. Freshness
// over name hug the bottom-leading corner. Tap deep-links into the app.
// Always dark — it's the night sky.
struct SkyObjectWidgetView: View {

    var entry: SkyObjectProvider.Entry
    @Environment(\.widgetFamily) private var environmentFamily

    /// Tinted / "Clear" Home Screen themes repaint every non-transparent
    /// pixel with a light vibrant material, so the legibility scrim behind
    /// the name block — a black gradient — comes back as a WHITE wash that
    /// hurts the very text it exists to help. Dropped in those modes, along
    /// with some star density (the field turns to white noise there).
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    private var isMasked: Bool { widgetRenderingMode != .fullColor }

    /// The badges grow with the Text Size (see `Artist+TypeScale`), so the
    /// footprints the constellation names give way to must too.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Explicit family, for rendering this tile OUTSIDE a widget host —
    /// `\.widgetFamily` is read-only, so the DEBUG art exporter can't inject
    /// it and every render would otherwise fall back to the environment's
    /// default (medium) geometry. Real widgets leave this nil and read the
    /// environment as before.
    var familyOverride: WidgetFamily? = nil

    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    /// Large and extra-large share the roomy treatment — denser star
    /// field, bigger promoted pin, the altitude/bearing line. Extra
    /// large (iPad always; iPhone since iOS 27) is the same postcard,
    /// panoramic: everything derives from `geo.size`, so it just
    /// breathes wider.
    private var isExpansive: Bool {
        family == .systemLarge || family == .systemExtraLarge
    }
    
    private var isLandscape: Bool {
        family == .systemMedium || family == .systemExtraLarge
    }

    @MainActor
    private var category: POICategory? {
        switch entry.entity.skyObject {
        case .star(let s):     .followedStar(s)
        case .sun:             .sun
        case .moon:            .moon
        case .planet(let p):   .planet(p)
        case .constellation:   .constellation
        case .spacecraft(let c): .spacecraft(c)
        case nil:              nil
        }
    }

    /// The Moon's real lit face for this entry's instant and place. The
    /// widget is a postcard of one moment, so a generic full disc is the
    /// one thing it must not show. Latitude falls back to the equator (no
    /// mirror) when the app has never parked an origin.
    @MainActor
    private func lunarPhase(for category: POICategory?) -> LunarPhase? {
        guard let category else { return nil }
        return BadgePhase.of(category, date: entry.date,
                             latitude: .degrees(entry.origin?.latDeg ?? 0))
    }

    /// Stars — the Sun included — wear the pointy 5-corner squircle,
    /// exactly like the app's labels; planetoids stay rounded.
    private func labelStyle(for category: POICategory) -> POILabelView.LabelStyle {
        switch category {
        case .sun, .followedStar, .namedStar: .star
        default:                              .planetoids
        }
    }

    var body: some View {
        Group {
            if family == .accessoryCircular {
                accessory
            } else {
                postcard
            }
        }
        .preferredColorScheme(.dark)
//        .environment(\.colorScheme, .dark)     // the night sky is dark; so are we
        .widgetURL(URL(string: "ephoemerous://object/\(entry.entity.id)"))
    }

    // MARK: Postcard (system families)

    
    private var postcard: some View {
        GeometryReader { geo in
            let snapshot = SkySnapshot(entity: entry.entity,
                                       date:   entry.date,
                                       origin: entry.origin,
                                       size:   geo.size,
                                       isLandscape: isLandscape)

            ZStack(alignment: .topLeading) {
                // The map: cartography canvas + flat body labels. Large
                // has room for a denser naked-eye field.
                Group {
                let bodies = snapshot.bodies(excluding: entry.entity.id, in: geo.size)
                Canvas { ctx, size in
                    // Extra large earns the densest field — panorama room.
                    snapshot.draw(in: &ctx, size: size,
                                 magnitudeLimit: isMasked                    ? 4.0
                                               : family == .systemExtraLarge ? 5.6
                                               : isExpansive                 ? 5.2 : 4.5,
                                 avoid: footprints(bodies: bodies,
                                                   pinned: snapshot.pinnedConstellation == nil ? category : nil,
                                                   in: size))
                }
                ForEach(bodies,
                        id: \.2) { category, sc, name in
                    flatLabel(category, name: name)
                        .position(sc)
                }

                // Legibility scrim under the bottom-leading text.
//                LinearGradient(colors: [.clear, .clear, .black.opacity(0.75)],
//                               startPoint: .center, endPoint: .bottom)
//                    .allowsHitTesting(false)

                // Constellations have no badge or dot — their solid-traced
                // figure (see SkySnapshot.draw) IS the promoted label.
                if let category, snapshot.pinnedConstellation == nil {
                    promotedPin(category, in: geo.size)
                }
                }
                // The sky is always NIGHT. `.preferredColorScheme` doesn't
                // reach a widget's colours, so on a light Home Screen the
                // assets resolved their LIGHT variants — the star ink a dim
                // warm brown, `.secondary` names a dark grey: haze on navy.
                .environment(\.colorScheme, .dark)

                // Freshness over name, hugging the corner like Find My.
                // Large adds the altitude/bearing readout — the extra
                // line the taller tile actually has room to earn.
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    VStack(alignment: .leading, spacing: 0) {
                        Text(entry.freshnessLabel)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(entry.entity.name)
                            .font(.system(.headline, design: .serif, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if isExpansive, let altAz = snapshot.altitudeAzimuthLabel {
                            Text(altAz)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 18)
                    .padding(.trailing, 36)
                    .padding(.bottom, 16)
                    .padding(.top, 8)
//                    .border(.green)
                    .background {
                        // No scrim under a masking host — see `isMasked`.
                        ContainerRelativeShape()
                            .fill (isMasked ? AnyShapeStyle(.clear) : AnyShapeStyle(
//                                .ultraThinMaterial.opacity(0.55)
                        LinearGradient(colors: [.black.opacity(0.45), .clear],
                                       startPoint: .bottom, endPoint: .top)
//                                RadialGradient(stops: [
//                                    .init(color: .clear              , location: 0.5),
//                                    .init(color: .black.opacity(0.75), location: 0.0),
//                                ], center: .bottomLeading, startRadius: 24, endRadius: 150)
                        ))
//                            .padding(6)
//                            .shadow(radius: 3.5)
                    }
                    .preferredColorScheme(.dark)
                }
                
            }
        }
        .containerBackground(for: .widget) {
            Artist.shared.canvasBackground
        }
    }

    /// An UNPROMOTED label — badge + trailing name, exactly the app's
    /// flat POI treatment at this zoom (names ride the tier reveal).
    @MainActor
    private func flatLabel(_ category: POICategory, name: String) -> some View {
        let style = Artist.shared.poiStyle(for: category)
        return POILabelView(category:    category,
                            text:        name,
                            labelStyle:  labelStyle(for: category),
                            badgeReveal: POILabelView.tierReveal(scale: 110,
                                                                 threshold: style.badgeIn),
                            nameReveal:  POILabelView.tierReveal(scale: 110,
                                                                 threshold: style.textIn),
                            phase:       lunarPhase(for: category))
    }

    /// The promoted pin: the badge sits ON the object's projection (see
    /// SkySnapshot), enlarged for the tile — the roomier families bigger,
    /// proportionate to the tile. No halo behind it: the badge's own glow
    /// is the lift, as on the app's sky.
    ///
    /// LAID OUT at the enlarged size (`sizeScale`), not `.scaleEffect`-ed —
    /// a scale effect only stretches the badge's shadow-rendered bitmap
    /// (soft rings, soft bands), the reason the app's pin stopped using it.
    @MainActor
    private func promotedPin(_ category: POICategory, in size: CGSize) -> some View {
        POILabelView(category:   category,
                            text:       "",
                            labelStyle: labelStyle(for: category),
                            nameReveal: 0,
                            phase:      lunarPhase(for: category),
                            richDetail: true,          // big enough to carry it, like the app's pin
                            sizeScale:  pinScale(for: category))
            .position(Pin.badgeCentre(in: size, isLandscape: isLandscape))
    }

    /// The pin's enlargement — the roomier families bigger, the Sun a
    /// touch smaller on the pocket tiles. ▼ TWEAK the pin's size per family ▼
    private func pinScale(for category: POICategory) -> CGFloat {
        family == .systemExtraLarge ? 2.6
        : family == .systemLarge    ? 2.2
        : category == .sun          ? 1.5
        : category == .moon         ? 1.8 : 1.9
    }

    // MARK: Footprints
    // Where the tile's marks sit, so the constellation names can give way
    // to them — the app's rule (labels never overlap) on the postcard.

    /// Each body's badge and (revealed) name, the pinned badge, and the
    /// name block in the bottom-leading corner.
    @MainActor
    private func footprints(bodies: [(POICategory, CGPoint, String)],
                            pinned: POICategory?, in size: CGSize) -> [CGRect] {
        let a      = Artist.shared
        let type   = a.typeScale(dynamicTypeSize)
        let font   = a.labelFont(.footnote, size: dynamicTypeSize)
        var rects: [CGRect] = []

        for (category, p, name) in bodies {
            let style = a.poiStyle(for: category)
            let d     = style.badgeSize * type + a.poiTextBorderWidth * 2
            rects.append(CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d))
            // The name trails the badge, as `POILabelView` draws it.
            guard POILabelView.tierReveal(scale: 110, threshold: style.textIn) > 0.01 else { continue }
            let w = (name as NSString).size(withAttributes: [.font: font]).width + 3
            rects.append(CGRect(x: p.x + (style.badgeSize / 2 + 6) * type, y: p.y - font.lineHeight / 2,
                                width: w, height: font.lineHeight))
        }
        if let pinned {
            let c = Pin.badgeCentre(in: size, isLandscape: isLandscape)
            let d = a.poiStyle(for: pinned).badgeSize * pinScale(for: pinned) * type
                  * (a.poiHasRings(pinned) ? a.saturnRingOuter.width : 1)
            rects.append(CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d))
        }
        // Freshness + name (+ altitude on the roomy tiles), bottom-leading.
        let block: CGFloat = isExpansive ? 78 : 60
        rects.append(CGRect(x: 0, y: size.height - block, width: size.width * 0.6, height: block))
        return rects.map { $0.insetBy(dx: -2, dy: -2) }
    }

    // MARK: Accessory (lock screen)

    private var accessory: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let category {
                POILabelView(category:   category,
                             text:        "",
                             labelStyle:  labelStyle(for: category),
                             nameReveal:  0,
                             phase:       lunarPhase(for: category))
            } else {
                Image(systemName: "sparkles")
            }
        }
    }
}

// MARK: - Widget
struct EphoemerousWidgets: Widget {
    let kind: String = "EphoemerousWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind:     kind,
                               intent:   SkyObjectWidgetIntent.self,
                               provider: SkyObjectProvider()) { entry in
            SkyObjectWidgetView(entry: entry)
                
        }
        .configurationDisplayName("Sky Object")
        .description("A star, planet, the Sun or the Moon — live on your sky map.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .systemExtraLarge, .accessoryCircular])
        // Canvas background and pin overlay must share one coordinate
        // space — margins are managed by hand (see Pin).
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    EphoemerousWidgets()
} timeline: {
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.moon), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.sun), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.planet(.mars)), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.planet(.jupiter)), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.star(.mockStars[0])), origin: nil)
}

#Preview(as: .systemMedium) {
    EphoemerousWidgets()
} timeline: {
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.moon), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.sun), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.planet(.mars)), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.planet(.jupiter)), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.star(.mockStars[0])), origin: nil)
}

#Preview(as: .systemLarge) {
    EphoemerousWidgets()
} timeline: {
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.moon), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.sun), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.planet(.mars)), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.planet(.jupiter)), origin: nil)
    SkyObjectEntry(date: .now, captured: .now,
                   entity: SkyObjectEntity(.star(.mockStars[0])), origin: nil)
}

//#Preview(as: .systemExtraLarge) {
//    EphoemerousWidgets()
//} timeline: {
//    SkyObjectEntry(date: .now, captured: .now,
//                   entity: SkyObjectEntity(.moon), origin: nil)
//    SkyObjectEntry(date: .now, captured: .now,
//                   entity: SkyObjectEntity(.star(.mockStars[0])), origin: nil)
//}


//#Preview(as: .systemExtraLargePortrait) {
//    EphoemerousWidgets()
//} timeline: {
//    SkyObjectEntry(date: .now, captured: .now,
//                   entity: SkyObjectEntity(.moon), origin: nil)
//    SkyObjectEntry(date: .now, captured: .now,
//                   entity: SkyObjectEntity(.sun), origin: nil)
//    SkyObjectEntry(date: .now, captured: .now,
//                   entity: SkyObjectEntity(.planet(.mars)), origin: nil)
//    SkyObjectEntry(date: .now, captured: .now,
//                   entity: SkyObjectEntity(.planet(.jupiter)), origin: nil)
//    SkyObjectEntry(date: .now, captured: .now,
//                   entity: SkyObjectEntity(.star(.mockStars[0])), origin: nil)
//}

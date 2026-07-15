import WidgetKit
import SwiftUI
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
    static let lift: CGFloat = 34

    /// The precise-location dot — where the camera lands the object.
    /// Near the tile's midpoint (Find My plants its pin there), a touch
    /// trailing so the lifted badge reads top-trailing. ▼ TWEAK ▼
    static func dot(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.73, y: size.height * 0.50)
    }

    /// Badge centre — lifted straight above the dot.
    static func badgeCentre(in size: CGSize) -> CGPoint {
        let d = dot(in: size)
        return CGPoint(x: d.x, y: d.y - lift)
    }
}

// MARK: - Sky snapshot
// The REAL sky at `date` from the observer's origin — the same
// stereographic pipeline the app renders with (`SkyCamera` +
// `EProjection`, compiled into this target), drawn once into a
// widget-sized Canvas. The camera is offset so the object's projection
// lands exactly on the pin's precise-location dot.
private struct SkySnapshot {

    let camera: SkyCamera
    let date:   Date
    /// Set when the PINNED object is a constellation — it has no badge
    /// or dot; instead its stick-figure is traced solid on the map.
    let pinnedConstellation: EConstellation?

    @MainActor
    init(entity: SkyObjectEntity, date: Date,
         origin: (latDeg: Double, lonDeg: Double)?, size: CGSize) {
        self.date = date
        if case .constellation(let c) = entity.skyObject {
            pinnedConstellation = c
        } else {
            pinnedConstellation = nil
        }

        let lat = Angle.degrees(origin?.latDeg ?? 51.48)   // Greenwich fallback
        let lon = Angle.degrees(origin?.lonDeg ?? 0)
        let viewpoint = EProjection.Viewpoint(
            originVector: Angle.spherePoint(latitude: lat, longitude: lon),
            planeVector:  Angle.spherePoint(latitude: .radians(-lat.radians),
                                            longitude: lon + .radians(.pi)))
        let sidereal = -EPrecession.lst(for: date, longitude: lon)

        // ▼ TWEAK the postcard zoom here — screen pt per projection unit ▼
        let scale: CGFloat = 110

        // Offset the camera so the object projects ONTO THE PIN DOT —
        // screen() = size/2 + (p.x·s, −p.y·s) + offset, so solve for
        // offset with the dot as the wanted screen point. Objects that
        // fail to project (antipodal degeneracy) fall back to zenith-ish.
        var offset = CGSize.zero
        if let target = Self.vector(for: entity, date: date, sidereal: sidereal),
           let p = EProjection.project(target, viewpoint: viewpoint) {
            let dot = Pin.dot(in: size)
            offset = CGSize(width:  dot.x - size.width  / 2 - p.x * scale,
                            height: dot.y - size.height / 2 + p.y * scale)
        }

        camera = SkyCamera(scale:     scale,
                           offset:    offset,
                           size:      size,
                           viewpoint: viewpoint,
                           sidereal:  sidereal)
    }

    /// The object's position in the sidereally-rotated frame the camera
    /// projects from — same helpers the app's overlay layers use.
    @MainActor
    private static func vector(for entity: SkyObjectEntity, date: Date,
                               sidereal: Angle) -> SIMD3<Double>? {
        switch entity.skyObject {
        case .star(let s):
            return s.equatorialVector.sidereallyRotated(by: sidereal)
        case .sun:
            let lambda = ESunPosition.eclipticLongitude(for: date)
            return SIMD3.eclipticPoint(lambda: lambda).sidereallyRotated(by: sidereal)
        case .moon:
            let (vec, _, _) = EMoonPosition.vector(for: date, siderealOffset: sidereal)
            return vec
        case .planet(let p):
            return EPlanetPosition.allVectors(for: date, siderealOffset: sidereal)
                .first { $0.0 == p }?.1
        case .constellation(let c):
            // The figure-star centroid — the same anchor the app labels
            // the constellation at — so the FIGURE parks on the pin spot.
            guard let anchor = ConstellationLines.shared.labelAnchors[c] else { return nil }
            return EPrecession.equatorialVector(ra: anchor.ra, dec: anchor.dec)
                .sidereallyRotated(by: sidereal)
        case nil:
            return nil
        }
    }

    /// The solar-system bodies as (category, screen point, name) — the
    /// map furniture. The pinned object is excluded (it IS the pin), as
    /// is anything close enough to collide with the lifted badge.
    @MainActor
    func bodies(excluding pinned: String, in size: CGSize) -> [(POICategory, CGPoint, String)] {
        var out: [(POICategory, CGPoint, String)] = []
        let badge = Pin.badgeCentre(in: size)

        func admit(_ sc: CGPoint?) -> CGPoint? {
            guard let sc,
                  sc.x > 8, sc.x < size.width - 8,
                  sc.y > 8, sc.y < size.height - 8,
                  hypot(sc.x - badge.x, sc.y - badge.y) > 44 else { return nil }
            return sc
        }

        if pinned != "sun" {
            let lambda = ESunPosition.eclipticLongitude(for: date)
            if let sc = admit(camera.screen(equatorial: .eclipticPoint(lambda: lambda))) {
                out.append((.sun, sc, ESkyObject.sun.displayName))
            }
        }
        if pinned != "moon" {
            let (vec, _, _) = EMoonPosition.vector(for: date, siderealOffset: camera.sidereal)
            if let sc = admit(camera.screen(rotatedEquatorial: vec)) {
                out.append((.moon, sc, ESkyObject.moon.displayName))
            }
        }
        for (planet, vec, _, _) in EPlanetPosition.allVectors(for: date,
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
    @MainActor
    func draw(in ctx: inout GraphicsContext, size: CGSize) {
        // Stars to magnitude 4.5 — the naked-eye field, a few hundred dots.
        for star in StarDatabase.shared.workableStars where star.magnitude <= 4.5 {
            guard let sc = camera.screen(equatorial: star.equatorialVector),
                  sc.x > -4, sc.x < size.width + 4,
                  sc.y > -4, sc.y < size.height + 4 else { continue }
            let r = max(0.7, 2.4 - 0.4 * star.magnitude)
            ctx.fill(Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r,
                                            width: r * 2, height: r * 2)),
                     with: .color(star.spectralClass.color.opacity(
                        star.magnitude < 2 ? 0.95 : 0.65)))
        }

        // Constellation stick-figures — the app's quiet dotted grey; the
        // PINNED constellation is the hero and gets traced separately.
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
                if cons == pinnedConstellation {
                    hero.move(to: a)
                    hero.addLine(to: b)
                } else {
                    sticks.move(to: a)
                    sticks.addLine(to: b)
                }
            }
        }
        ctx.stroke(sticks,
                   with: .color(.white.opacity(0.16)),
                   style: StrokeStyle(lineWidth: 0.7, dash: [2, 3]))
        // The hero figure: a SOLID trace, like a selected constellation
        // in the app — the line IS the promoted label here.
        ctx.stroke(hero,
                   with: .color(.white.opacity(0.75)),
                   style: StrokeStyle(lineWidth: 1.2,
                                      lineCap: .round, lineJoin: .round))

        // Constellation names at their figure centroids — faint map ink.
        // The pinned one is skipped: the bottom-leading block names it.
        for (cons, anchor) in ConstellationLines.shared.labelAnchors
        where cons != pinnedConstellation {
            let vec = EPrecession.equatorialVector(ra: anchor.ra, dec: anchor.dec)
            guard let sc = camera.screen(equatorial: vec),
                  sc.x > 10, sc.x < size.width - 10,
                  sc.y > 10, sc.y < size.height - 10 else { continue }
            ctx.draw(Text(cons.localizedName.uppercased())
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.28)),
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
    @Environment(\.widgetFamily) private var family

    @MainActor
    private var category: POICategory? {
        switch entry.entity.skyObject {
        case .star(let s):     .followedStar(s)
        case .sun:             .sun
        case .moon:            .moon
        case .planet(let p):   .planet(p)
        case .constellation:   .constellation
        case nil:              nil
        }
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
        .environment(\.colorScheme, .dark)     // the night sky is dark; so are we
        .widgetURL(URL(string: "ephoemerous://object/\(entry.entity.id)"))
    }

    // MARK: Postcard (system families)

    private var postcard: some View {
        GeometryReader { geo in
            let snapshot = SkySnapshot(entity: entry.entity,
                                       date:   entry.date,
                                       origin: entry.origin,
                                       size:   geo.size)

            ZStack(alignment: .topLeading) {
                // The map: cartography canvas + flat body labels.
                Canvas { ctx, size in
                    snapshot.draw(in: &ctx, size: size)
                }
                ForEach(snapshot.bodies(excluding: entry.entity.id, in: geo.size),
                        id: \.2) { category, sc, name in
                    flatLabel(category, name: name)
                        .position(sc)
                }

                // Legibility scrim under the bottom-leading text.
                LinearGradient(colors: [.clear, .black.opacity(0.45)],
                               startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)

                // Constellations have no badge or dot — their solid-traced
                // figure (see SkySnapshot.draw) IS the promoted label.
                if let category, snapshot.pinnedConstellation == nil {
                    promotedPin(category, in: geo.size)
                }

                // Freshness over name, hugging the corner like Find My.
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    Text(entry.freshnessLabel)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(entry.entity.name)
                        .font(.system(.subheadline, design: .serif, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.leading, 16)
                .padding(.bottom, 18)
            }
        }
        .containerBackground(for: .widget) {
            EArtist.shared.canvasBackground
        }
    }

    /// An UNPROMOTED label — badge + trailing name, exactly the app's
    /// flat POI treatment at this zoom (names ride the tier reveal).
    @MainActor
    private func flatLabel(_ category: POICategory, name: String) -> some View {
        let style = EArtist.shared.poiStyle(for: category)
        return POILabelView(category:    category,
                            text:        name,
                            labelStyle:  labelStyle(for: category),
                            badgeReveal: POILabelView.tierReveal(scale: 110,
                                                                 threshold: style.badgeIn),
                            nameReveal:  POILabelView.tierReveal(scale: 110,
                                                                 threshold: style.textIn))
    }

    /// The promoted pin: the badge lifted above its precise-location dot
    /// — the object's projection lands ON the dot (see SkySnapshot).
    @MainActor
    private func promotedPin(_ category: POICategory, in size: CGSize) -> some View {
        let style = EArtist.shared.poiStyle(for: category)

        return ZStack {
            POILabelView(category:   category,
                         text:        "",
                         labelStyle:  labelStyle(for: category),
                         nameReveal:  0,
                         borderScaleCompensation: 1 / 3)
                .scaleEffect(2)
                .position(Pin.badgeCentre(in: size))

            // Precise-location dot — the object itself.
            Circle()
                .fill(style.gradientBottom)
                .frame(width: 6, height: 6)
                .shadow(color: .black.opacity(0.7), radius: 1.5)
                .position(Pin.dot(in: size))
        }
    }

    // MARK: Accessory (lock screen)

    private var accessory: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let category {
                POILabelView(category:   category,
                             text:        "",
                             labelStyle:  labelStyle(for: category),
                             nameReveal:  0)
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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
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

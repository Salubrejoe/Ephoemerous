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
        SkyObjectEntry(date: .now, entity: SkyObjectEntity(.moon), origin: nil)
    }

    @MainActor private func entry(for configuration: SkyObjectWidgetIntent) -> SkyObjectEntry {
        SkyObjectEntry(date:   .now,
                       entity: configuration.object ?? SkyObjectEntity(.moon),
                       origin: FavouritesStore().observerOrigin())
    }

    func snapshot(for configuration: SkyObjectWidgetIntent,
                  in context: Context) async -> SkyObjectEntry {
        await entry(for: configuration)
    }

    func timeline(for configuration: SkyObjectWidgetIntent,
                  in context: Context) async -> Timeline<SkyObjectEntry> {
        // The sky turns ~7.5° in 30 min — refresh on that beat so the map
        // stays honest without burning the widget refresh budget.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        return await Timeline(entries: [entry(for: configuration)], policy: .after(next))
    }
}

struct SkyObjectEntry: TimelineEntry {
    let date:   Date
    let entity: SkyObjectEntity
    /// Observer origin (degrees) the app last parked at — nil before the
    /// app has ever backgrounded; the map falls back to Greenwich.
    let origin: (latDeg: Double, lonDeg: Double)?
}

// MARK: - Sky snapshot
// The REAL sky at `date` from the observer's origin, centred on the
// object — the same stereographic pipeline the app renders with
// (`SkyCamera` + `EProjection`, compiled into this target), drawn once
// into a widget-sized Canvas. No ImageRenderer needed: WidgetKit
// rasterises the view itself, once per timeline entry.
private struct SkySnapshot {

    let camera: SkyCamera
    let date:   Date

    /// Widget-frame camera centred on the object's current sky position.
    @MainActor
    init(entity: SkyObjectEntity, date: Date,
         origin: (latDeg: Double, lonDeg: Double)?, size: CGSize) {
        self.date = date

        let lat = Angle.degrees(origin?.latDeg ?? 51.48)   // Greenwich fallback
        let lon = Angle.degrees(origin?.lonDeg ?? 0)
        let viewpoint = EProjection.Viewpoint(
            originVector: Angle.spherePoint(latitude: lat, longitude: lon),
            planeVector:  Angle.spherePoint(latitude: .radians(-lat.radians),
                                            longitude: lon + .radians(.pi)))
        let sidereal = -EPrecession.lst(for: date, longitude: lon)

        // ▼ TWEAK the postcard zoom here — screen pt per projection unit ▼
        let scale: CGFloat = 110

        // Offset the camera so the object's projection lands dead-centre
        // (the "concentric" framing). Objects that fail to project
        // (antipodal degeneracy) fall back to the zenith-centred view.
        var offset = CGSize.zero
        if let target = Self.vector(for: entity, date: date, sidereal: sidereal),
           let p = EProjection.project(target, viewpoint: viewpoint) {
            offset = CGSize(width: -p.x * scale, height: p.y * scale)
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
        case .constellation, nil:
            return nil
        }
    }

    /// Bright-star field + the dashed horizon — the postcard's cartography.
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
// The Find My postcard: the live sky map fills the tile, centred on the
// object (a precise-location dot marks it); the object's REAL POI badge
// rides top-trailing inside concentric rings — the promoted label; name
// + freshness sit bottom-leading over a legibility scrim. Tapping
// deep-links into the app focused on the object.
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

    var body: some View {
        Group {
            if family == .accessoryCircular {
                accessory
            } else {
                postcard
            }
        }
        .widgetURL(URL(string: "ephoemerous://object/\(entry.entity.id)"))
    }

    // MARK: Postcard (system families)

    private var postcard: some View {
        ZStack {
            // Precise-location dot — dead centre by construction (the
            // camera is offset so the object projects here).
            if let category {
                let style = EArtist.shared.poiStyle(for: category)
                Circle()
                    .fill(style.gradientBottom)
                    .frame(width: 6, height: 6)
                    .shadow(color: .black.opacity(0.5), radius: 1.5)
            }

            // Promoted label, top-trailing: the real badge in concentric
            // rings — the widget's echo of the app's promoted pin.
            if let category {
                VStack { HStack { Spacer(); promotedBadge(category) }; Spacer() }
                    .padding(10)
            }

            // Name + freshness, bottom-leading, over a scrim.
            VStack(alignment: .leading, spacing: 1) {
                Spacer()
                Text(entry.entity.name)
                    .font(.system(.subheadline, design: .serif, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                (Text(entry.entity.subtitle) + Text(" · ") +
                 Text(entry.date, style: .relative) + Text(" ago"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .containerBackground(for: .widget) {
            skyMap
        }
    }

    /// The badge inside concentric rings, Find My-pin style.
    private func promotedBadge(_ category: POICategory) -> some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.35))
                .frame(width: 40, height: 40)
            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 1.5)
                .frame(width: 40, height: 40)
            Circle()
                .stroke(.white.opacity(0.3), lineWidth: 1)
                .frame(width: 48, height: 48)
            POILabelView(category:   category,
                         text:        "",
                         nameReveal:  0,
                         borderScaleCompensation: 1 / 1.6)
                .scaleEffect(1.6)
        }
    }

    /// The full-bleed sky map, rendered by the app's own projection.
    private var skyMap: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let snapshot = SkySnapshot(entity: entry.entity,
                                           date:   entry.date,
                                           origin: entry.origin,
                                           size:   size)
                snapshot.draw(in: &ctx, size: size)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // Legibility scrim under the bottom-leading label.
            .overlay(
                LinearGradient(colors: [.clear, .black.opacity(0.45)],
                               startPoint: .center, endPoint: .bottom)
            )
        }
        .background(EArtist.shared.canvasBackground)
    }

    // MARK: Accessory (lock screen)

    private var accessory: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let category {
                POILabelView(category:   category,
                             text:        "",
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
    }
}

#Preview(as: .systemSmall) {
    EphoemerousWidgets()
} timeline: {
    SkyObjectEntry(date: .now, entity: SkyObjectEntity(.moon), origin: nil)
    SkyObjectEntry(date: .now, entity: SkyObjectEntity(.planet(.mars)), origin: nil)
}

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

// MARK: - Pin geometry
// One source of truth for the promoted-pin layout so the CAMERA (which
// must land the object's projection on the dot) and the OVERLAY (ring,
// cone, dot) agree to the pixel. Content margins are disabled on the
// widget, so canvas and overlay share the full-bleed coordinate space.
private enum Pin {
    static let ringRadius:  CGFloat = 20   // badge ring (inner stroke)
    static let haloRadius:  CGFloat = 24   // faint outer ring
    static let coneHeight:  CGFloat = 8
    static let coneHalf:    CGFloat = 5    // half-width of the cone base
    static let dotGap:      CGFloat = 3    // cone tip → dot centre
    static let inset:       CGFloat = 14   // ring centre inset from corner

    /// Badge-ring centre, top-trailing.
    static func ringCentre(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width - inset - haloRadius, y: inset + haloRadius)
    }

    /// The precise-location dot — under the ring, past the cone tail.
    /// THIS is where the camera lands the object.
    static func dot(in size: CGSize) -> CGPoint {
        let c = ringCentre(in: size)
        return CGPoint(x: c.x, y: c.y + ringRadius + coneHeight + dotGap + 3)
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
// The Find My postcard: the live sky map fills the tile; the object's
// REAL POI badge rides top-trailing inside concentric rings with a
// little cone tail pointing at its precise-location dot — the map is
// offset so the object genuinely sits there (a proper promoted label).
// Name + freshness hug the bottom-leading corner. Tap deep-links into
// the app focused on the object. Always dark — it's the night sky.
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
    @MainActor
    private var labelStyle: POILabelView.LabelStyle {
        switch entry.entity.skyObject {
        case .star, .sun: .star
        default:          .planetoids
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
            ZStack(alignment: .topLeading) {
                if let category {
                    promotedPin(category, in: geo.size)
                }

                // Name + freshness, hugging the corner like Find My.
                VStack(alignment: .leading, spacing: 0) {
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
                .padding(.leading, 8)
                .padding(.bottom, 6)
            }
        }
        .containerBackground(for: .widget) {
            skyMap.environment(\.colorScheme, .dark)
        }
    }

    /// The full promoted pin: badge in concentric rings, cone tail,
    /// precise-location dot — the object's projection lands ON the dot
    /// (see SkySnapshot's offset), so this reads as the app's promoted
    /// label planted in the live sky.
    @MainActor
    private func promotedPin(_ category: POICategory, in size: CGSize) -> some View {
        let c     = Pin.ringCentre(in: size)
        let dot   = Pin.dot(in: size)
        let style = EArtist.shared.poiStyle(for: category)

        return ZStack {
            // Cone tail — ring bottom down to just above the dot.
            ConeTail(base:  CGPoint(x: c.x, y: c.y + Pin.ringRadius - 1),
                     tip:   CGPoint(x: c.x, y: dot.y - Pin.dotGap),
                     half:  Pin.coneHalf)
                .fill(.white.opacity(0.9))

            // Concentric rings + badge.
            Circle()
                .fill(.black.opacity(0.35))
                .frame(width: Pin.ringRadius * 2, height: Pin.ringRadius * 2)
                .position(c)
            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 1.5)
                .frame(width: Pin.ringRadius * 2, height: Pin.ringRadius * 2)
                .position(c)
            Circle()
                .stroke(.white.opacity(0.3), lineWidth: 1)
                .frame(width: Pin.haloRadius * 2, height: Pin.haloRadius * 2)
                .position(c)
            POILabelView(category:   category,
                         text:        "",
                         labelStyle:  labelStyle,
                         nameReveal:  0,
                         borderScaleCompensation: 1 / 1.6)
                .scaleEffect(1.6)
                .position(c)

            // Precise-location dot — the object itself.
            Circle()
                .fill(style.gradientBottom)
                .frame(width: 6, height: 6)
                .shadow(color: .black.opacity(0.5), radius: 1.5)
                .position(dot)
        }
    }

    /// Map-pin tail: a small triangle from the ring toward the dot.
    private struct ConeTail: Shape {
        let base: CGPoint
        let tip:  CGPoint
        let half: CGFloat
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to:    CGPoint(x: base.x - half, y: base.y))
            p.addLine(to: CGPoint(x: base.x + half, y: base.y))
            p.addLine(to: tip)
            p.closeSubpath()
            return p
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
                             labelStyle:  labelStyle,
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
    SkyObjectEntry(date: .now, entity: SkyObjectEntity(.moon), origin: nil)
    SkyObjectEntry(date: .now, entity: SkyObjectEntity(.planet(.mars)), origin: nil)
}

import WidgetKit
import SwiftUI
import AppIntents
import LoreKit

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
        SkyObjectEntry(date: .now, entity: SkyObjectEntity(.moon))
    }

    func snapshot(for configuration: SkyObjectWidgetIntent,
                  in context: Context) async -> SkyObjectEntry {
        SkyObjectEntry(date: .now,
                       entity: configuration.object ?? SkyObjectEntity(.moon))
    }

    func timeline(for configuration: SkyObjectWidgetIntent,
                  in context: Context) async -> Timeline<SkyObjectEntry> {
        let entry = SkyObjectEntry(date: .now,
                                   entity: configuration.object ?? SkyObjectEntity(.moon))
        // Static identity content for now — refresh hourly so a rename /
        // un-favourite eventually settles. Positions/ephemerides come later.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        return Timeline(entries: [entry], policy: .after(next))
    }
}

struct SkyObjectEntry: TimelineEntry {
    let date:   Date
    let entity: SkyObjectEntity
}

// MARK: - Entry view
// A postcard of the app: canvas-colour night ground, the object's REAL
// POI badge (same `POILabelView` + `EArtist.poiStyle` the canvas uses,
// compiled into this target), name in the serif voice beneath. Tapping
// deep-links into the app focused on the object.
struct SkyObjectWidgetView: View {

    var entry: SkyObjectProvider.Entry

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
        ZStack {
            if let category {
                VStack(spacing: 10) {
                    // Enlarged like the promoted pin — and like it, the
                    // casing stroke is pre-shrunk so the scale doesn't
                    // fatten the outline into a halo.
                    POILabelView(category:   category,
                                 text:        "",
                                 nameReveal:  0,
                                 borderScaleCompensation: 1 / 2.2)
                        .scaleEffect(2.2)
                        .frame(height: 44)
                    Text(entry.entity.name)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(entry.entity.subtitle)
                        .font(.system(.caption2, design: .serif))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .padding(4)
            } else {
                // Unresolvable configuration (star renamed away) — quiet
                // placeholder rather than a crash or a blank tile.
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .widgetURL(URL(string: "ephoemerous://object/\(entry.entity.id)"))
        .containerBackground(for: .widget) {
            EArtist.shared.canvasBackground
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
        .description("A star, planet, the Sun or the Moon — as it appears on your sky map.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

#Preview(as: .systemSmall) {
    EphoemerousWidgets()
} timeline: {
    SkyObjectEntry(date: .now, entity: SkyObjectEntity(.moon))
    SkyObjectEntry(date: .now, entity: SkyObjectEntity(.planet(.mars)))
}

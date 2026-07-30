import SwiftUI
import LoreKit

// MARK: - ESunDetailView
// Sun detail. DetailHeader on top, a single horizontal scroll of
// 100pt-tall fact cards below — no RememberButton (sun isn't
// favouritable). Mirrors the constellation roster's card shape so
// the family of detail views shares one rhythm:
//
//   • event cards (civil dawn → civil dusk) tint yellow
//   • physical + coordinate cards stay neutral

struct ESunDetailView: View {
    @Environment(EAppState.self) var state
    @Environment(\.detailCollapsed) private var collapsed

    private var lambda: Angle { ESunPosition.eclipticLongitude(for: state.observationDate) }
    private var coords: (ra: Angle, dec: Angle) { ESunPosition.equatorialCoords(lambda: lambda) }

    private let accent = Color.yellow

    /// Civil-twilight anchors for the current observation date +
    /// observer latitude — re-evaluated whenever either changes, so
    /// the capsule's gradient stretches the bright zone for summer
    /// and narrows it for winter.
    private var anchors: SunDayAnchors {
        ESunPosition.dayAnchors(
            for: state.observationDate,
            latitude: state.origin.latitude.degrees
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:         Strings.Bodies.sun,
                subtitle:      String(localized: "G-type star"),
                accent:        accent,
                icon:          {
                    POILabelView(
                        category: .sun,
                        text: "",
                        labelStyle: .star
                    )
                },
                leadingSymbol: .share,
                onLeading:     {},
                postcard:      state.postcard(for: .sun),
                onDismiss:     { state.dismissDetail() }
            )
            
            if !collapsed {
                DayCapsule(
                    tint:      accent,
                    knobGlyph: .symbol(.sunMaxFill),
                    knobDate:  Bindable(state).observationDate
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                DetailStatList(stats: [
                    .init(label: String(localized: "Right ascension"), value: raString),
                    .init(label: String(localized: "Declination"),     value: decString),
                    .init(label: String(localized: "Distance"),        value: "1 AU (149.6M km)"),
                    .init(label: String(localized: "Diameter"),        value: "1,391,000 km"),
                    .init(label: String(localized: "Apparent magnitude"), value: "−26.7"),
                ])
                    .padding(.top, 16)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Coord formatting

    /// RA → "Hh MMm" (round, no seconds — the bottom-third detent
    /// doesn't have room for HH:MM:SS in a 110pt card).
    private var raString: String {
        let hours = coords.ra.degrees / 15
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return String(format: "%dh%02dm", h, m)
    }

    /// Dec → "DD°" (round, no minutes/seconds).
    private var decString: String {
        let d = Int(coords.dec.degrees.rounded())
        return "\(d)°"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ESunDetailView()
    }
    .environment(EAppState())
}



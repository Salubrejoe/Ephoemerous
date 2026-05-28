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
    private let weather = EWeatherService.shared

    private var lambda: Angle { ESunPosition.eclipticLongitude(for: state.observationDate) }
    private var coords: (ra: Angle, dec: Angle) { ESunPosition.equatorialCoords(lambda: lambda) }
    private var lat: Double { state.origin.latitude.degrees }
    private var lon: Double { state.origin.longitude.degrees }

    private let accent = Color.yellow

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:         "Sol",
                subtitle:      "G-type star",
                accent:        accent,
                icon:          { POIBadgeView(category: .sun) },
                leadingSymbol: "square.and.arrow.up",
                onLeading:     {},
                onDismiss:     { state.dismissDetail() }
            )
            DayCapsule(events: dayEvents)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            roster
                .padding(.top, 16)
            Spacer(minLength: 0)
        }
        .task(id: "\(lat),\(lon),\(state.observationDate)") {
            await weather.fetch(latitude: lat, longitude: lon, date: state.observationDate)
        }
    }

    /// Sun events for the DayCapsule — every event the weather
    /// service knows about, positioned on the 24h gradient by their
    /// wall-clock time. Bright events (sunrise / noon / sunset) get
    /// the yellow accent; civil dawn / dusk fade to a softer tint
    /// so the eye reads them as the bookends they are.
    private var dayEvents: [DayCapsule.Event] {
        guard let e = weather.sunEvents else { return [] }
        var out: [DayCapsule.Event] = []
        if let v = e.civilDawn { out.append(.init(time: v, label: "Civil dawn", color: Color.white.opacity(0.5))) }
        if let v = e.sunrise   { out.append(.init(time: v, label: "Sunrise",    color: accent)) }
        if let v = e.solarNoon { out.append(.init(time: v, label: "Noon",       color: accent)) }
        if let v = e.sunset    { out.append(.init(time: v, label: "Sunset",     color: accent)) }
        if let v = e.civilDusk { out.append(.init(time: v, label: "Civil dusk", color: Color.white.opacity(0.5))) }
        return out
    }

    // MARK: Roster

    /// Same 100-pt fixed row height as the constellation roster +
    /// star detail's stats grid — keeps the detail family in rhythm.
    private var rosterHeight: CGFloat { 100 }

    private var roster: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                physicalCards
                coordCards
            }
            .padding(.horizontal, 16)
        }
        .frame(height: rosterHeight)
    }

    // MARK: Card groups

    // Event cards are gone — the day's events are now on the
    // DayCapsule's gradient. Only physical + coordinate cards
    // remain in the horizontal roster.

    private var physicalCards: some View {
        Group {
            card(icon: "sparkles", accentTinted: false, value: "-26.7",   label: "Magnitude")
            card(icon: "ruler",    accentTinted: false, value: "1.0 AU",  label: "Distance")
        }
    }

    private var coordCards: some View {
        Group {
            card(icon: "arrow.left.arrow.right", accentTinted: false,
                 value: raString,  label: "RA")
            card(icon: "arrow.up.arrow.down", accentTinted: false,
                 value: decString, label: "Dec")
        }
    }

    // MARK: Card

    /// Same card shape as `EConstellationDetailView.StarCard` —
    /// fixed slot heights (icon 24, value 22, label 14), 110pt
    /// width, tertiary-fill rounded rect. Inlined here rather than
    /// shared because the moon detail will want a different default
    /// icon size for its phase glyph and it's simpler to keep two
    /// near-identical structs than fight a generic over it.
    private func card(icon: String, accentTinted: Bool, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accentTinted ? accent : .secondary)
                .frame(height: 24)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .monospacedDigit()
                .frame(height: 22)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)
                .frame(height: 14)
        }
        .frame(width: 110)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 14)
        .background(Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

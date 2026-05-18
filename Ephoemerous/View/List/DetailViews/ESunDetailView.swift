import SwiftUI

// MARK: - ESunDetailView

struct ESunDetailView: View {
    @Environment(EAppState.self) var state
    private let weather = EWeatherService.shared

    private var lambda: Angle { ESunPosition.eclipticLongitude(for: state.observationDate) }
    private var coords: (ra: Angle, dec: Angle) { ESunPosition.equatorialCoords(lambda: lambda) }
    private var lat: Double { state.origin.latitude.degrees }
    private var lon: Double { state.origin.longitude.degrees }

    private let accent = Color.yellow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EDetailSubtitle(text: "G-type  5,778 K  radius 696,000 km")
                eventsSection
                Divider().padding(.bottom, 24)
                coordinatesSection
                Divider().padding(.bottom, 24)
                physicalSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Sol")
        .navigationBarTitleDisplayMode(.large)
        .task(id: "\(lat),\(lon),\(state.observationDate)") {
            await weather.fetch(latitude: lat, longitude: lon, date: state.observationDate)
        }
    }

    private var eventsSection: some View {
        Group {
            EDetailSectionLabel(text: "Today")
            SunEventsTimeline(weather: weather)
                .padding(.bottom, 28)
        }
    }

    private var coordinatesSection: some View {
        Group {
            EDetailSectionLabel(text: "Equatorial coordinates")
            ECoordinateDials(ra: coords.ra, dec: coords.dec, accent: accent)
                .padding(.bottom, 28)
        }
    }

    private var physicalSection: some View {
        Group {
            EDetailSectionLabel(text: "Physical")
            EDetailPhysicalRow(label: "Apparent magnitude", value: "-26.74",   isLast: false)
            EDetailPhysicalRow(label: "Distance",           value: "1.000 AU", isLast: false)
            EDetailPhysicalRow(label: "Ecliptic longitude",
                               value: String(format: "%.3f deg", lambda.degrees), isLast: true)
        }
    }
}

// MARK: - Sun events timeline

private struct SunEventsTimeline: View {
    let weather: EWeatherService

    var body: some View {
        if weather.isLoading {
            Text("Fetching...")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else if let e = weather.sunEvents {
            VStack(alignment: .leading, spacing: 0) {
                if let v = e.civilDawn { SunEventRow(name: "Civil dawn",  time: v, style: .dim,    isLast: false) }
                if let v = e.sunrise   { SunEventRow(name: "Sunrise",     time: v, style: .bright, isLast: false) }
                if let v = e.solarNoon { SunEventRow(name: "Solar noon",  time: v, style: .noon,   isLast: false) }
                if let v = e.sunset    { SunEventRow(name: "Sunset",      time: v, style: .bright, isLast: false) }
                if let v = e.civilDusk { SunEventRow(name: "Civil dusk",  time: v, style: .dim,    isLast: true)  }
            }
        } else if let err = weather.error {
            Text(err)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
private struct SunEventRow: View {
    enum DotStyle { case dim, bright, noon }

    let name: String
    let time: Date
    let style: DotStyle
    let isLast: Bool

    private var dotColor: Color {
        switch style {
        case .dim:    return Color.primary.opacity(0.25)
        case .bright: return Color.yellow
        case .noon:   return Color.yellow
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                if !isLast {
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 0.5)
                        .frame(maxHeight: .infinity)
                        .offset(y: 14)
                }
                ZStack {
                    if style == .noon {
                        Circle()
                            .fill(Color.yellow.opacity(0.15))
                            .frame(width: 16, height: 16)
                    }
                    Circle()
                        .fill(dotColor)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 16, height: 44)

            Text(name)
                .font(.callout)
                .foregroundStyle(style == .noon ? .primary : .secondary)
            Spacer()
            Text(time.timeString)
                .font(.callout)
                .monospacedDigit()
                .fontDesign(.serif)
                .foregroundStyle(style == .noon ? .primary : .secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ESunDetailView()
    }
    .environment(EAppState())
}

import SwiftUI

struct ENSSunDetailView: View {
    @Environment(EAppState.self) var state
    private let weather = EWeatherService.shared
    private var lambda: Angle { ENSSunLayer.sunEclipticLongitude(for: state.observationDate) }
    private var coords: (ra: Angle, dec: Angle) { ENSSunLayer.equatorialCoords(lambda: lambda) }
    private var lat: Double { state.origin.latitude.degrees }
    private var lon: Double { state.origin.longitude.degrees }
    private let accent = Color.yellow
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sol")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.leading, 4)
                HStack {
                    HStack(spacing: 8) {
                        Image(symbol: .rightAscension)
                        Text("\(coords.ra.hmsString)")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(.regularMaterial)
                    )
                    HStack(spacing: 8) {
                        Image(symbol: .declination)
                        Text("\(coords.dec.dmsString)")
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(.regularMaterial)
                    )
                }
                .font(.footnote)
                .monospaced()
                .foregroundStyle(.secondary)
                .padding(.bottom)
                LazyVGrid(columns: cols, spacing: 12) {
                    ENSTile(
                        label: "Ecliptic Longitude",
                        value: String(format: "%.3f°", lambda.degrees),
                        accent: accent,
                        symbol: .calendar
                    )
                    ENSTile(
                        label: "Spectral Class",
                        value: "G",
                        accent: accent,
                        symbol: .calendar
                    )
                    ENSTile(
                        label: "Magnitude",
                        value: "-26.74",
                        accent: accent,
                        symbol: .calendar
                    )
                    ENSTile(
                        label: "Distance",
                        value: "1.000 AU",
                        accent: accent,
                        symbol: .calendar
                    )
                    ENSTile(
                        label: "Temperature",
                        value: "5,778 K",
                        accent: accent,
                        symbol: .calendar
                    )
                    ENSTile(
                        label: "Radius",
                        value: "696,000 km",
                        accent: accent,
                        symbol: .calendar
                    )
                }
                ENSSunEventsGrid(weather: weather, accent: accent)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
//        .navigationTitle("Sun")
//        .navigationBarTitleDisplayMode(.large)
        .task(id: "\(lat),\(lon),\(state.observationDate)") {
            await weather.fetch(latitude: lat, longitude: lon, date: state.observationDate)
        }
    }
}

private struct ENSSunEventsGrid: View {
    let weather: EWeatherService
    let accent: Color
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        if weather.isLoading {
            ENSTile(label: "Events", value: "Fetching…", accent: accent, symbol: .calendar)
        } else if let e = weather.sunEvents {
            LazyVGrid(columns: cols, spacing: 12) {
                if let v = e.civilDawn {
                    ENSTile(
                        label: "Civil Dawn",
                        value: v.timeString,
                        accent: accent,
                        symbol: .calendar
                    )
                }
                if let v = e.sunrise   {
                    ENSTile(
                        label: "Sunrise",
                        value: v.timeString,
                        accent: accent,
                        symbol: .calendar
                    )
                }
                if let v = e.solarNoon {
                    ENSTile(
                        label: "Solar Noon",
                        value: v.timeString,
                        accent: accent,
                        symbol: .calendar
                    )
                }
                if let v = e.sunset    {
                    ENSTile(
                        label: "Sunset",
                        value: v.timeString,
                        accent: accent,
                        symbol: .calendar
                    )
                }
                if let v = e.civilDusk {
                    ENSTile(
                        label: "Civil Dusk",
                        value: v.timeString,
                        accent: accent,
                        symbol: .calendar
                    )
                }
            }
        } else if let err = weather.error {
            ENSTile(label: "Error", value: err, accent: accent, symbol: .warning)
        }
    }
}

struct ENSTile: View {
    let label: String
    let value: String
    let accent: Color
    let symbol: Strings.Symbols
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(symbol: symbol)
                    .imageScale(.small)
                Text(label)
            }
            .font(.footnote)
            .foregroundStyle(accent.opacity(0.8))
            .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(.title3.bold())
                .monospaced()
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.3)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight:  66, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(accent.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

struct ENSBodyCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.bottom, 6)
            VStack(spacing: 0) { content() }
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08), lineWidth: 0.5))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct ENSBodyRow: View {
    let label: String; let value: String
    var body: some View {
        HStack { Text(label).font(.callout).foregroundStyle(.secondary); Spacer(); Text(value).font(.callout.monospacedDigit()).foregroundStyle(.primary) }
        .padding(.horizontal, 16).padding(.vertical, 12)
        Divider().opacity(0.3).padding(.horizontal, 16)
    }
}

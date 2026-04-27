import SwiftUI

struct ENSSunDetailView: View {
    @Environment(EAppState.self) var state

    private let weather = EWeatherService.shared

    private var lambda: Angle { ENSSunLayer.sunEclipticLongitude(for: state.observationDate) }
    private var coords: (ra: Angle, dec: Angle) { ENSSunLayer.equatorialCoords(lambda: lambda) }

    // Degrees from EAppState.origin
    private var lat: Double { state.origin.latitude.degrees }
    private var lon: Double { state.origin.longitude.degrees }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // ── Hero ──────────────────────────────────────────────────
//                ZStack {
//                    Circle()
//                        .fill(RadialGradient(
//                            colors: [Color.yellow.opacity(0.45), .clear],
//                            center: .center, startRadius: 0, endRadius: 90))
//                        .frame(width: 180, height: 180)
//                    Circle()
//                        .fill(RadialGradient(
//                            colors: [.white, .yellow, Color(red: 1, green: 0.6, blue: 0)],
//                            center: .center, startRadius: 0, endRadius: 30))
//                        .frame(width: 54, height: 54)
//                        .shadow(color: .yellow, radius: 16)
//                }
//                .padding(.top, 8)

                // ── Sun Events ────────────────────────────────────────────
                ENSBodyCard(title: "Sun Events") {
                    if weather.isLoading {
                        ENSBodyRow(label: "Fetching…", value: "")
                    } else if let e = weather.sunEvents {
                        if let v = e.civilDawn  { ENSBodyRow(label: "Civil Dawn",  value: v.timeString) }
                        if let v = e.sunrise    { ENSBodyRow(label: "Sunrise",     value: v.timeString) }
                        if let v = e.solarNoon  { ENSBodyRow(label: "Solar Noon",  value: v.timeString) }
                        if let v = e.sunset     { ENSBodyRow(label: "Sunset",      value: v.timeString) }
                        if let v = e.civilDusk  { ENSBodyRow(label: "Civil Dusk",  value: v.timeString) }
                    } else if let err = weather.error {
                        ENSBodyRow(label: "Error", value: err)
                    } else {
                        ENSBodyRow(label: "Unavailable", value: "")
                    }
                }

                // ── Coordinates ───────────────────────────────────────────
                ENSBodyCard(title: "Coordinates") {
                    ENSBodyRow(label: "Right Ascension",    value: coords.ra.hmsString)
                    ENSBodyRow(label: "Declination",        value: coords.dec.dmsString)
                    ENSBodyRow(label: "Ecliptic longitude", value: String(format: "%.3f°", lambda.degrees))
                }

                // ── Physical ──────────────────────────────────────────────
                ENSBodyCard(title: "Physical") {
                    ENSBodyRow(label: "Type",        value: "G-type main-sequence")
                    ENSBodyRow(label: "Distance",    value: "1.000 AU")
                    ENSBodyRow(label: "Magnitude",   value: "-26.74")
                    ENSBodyRow(label: "Temperature", value: "5,778 K")
                    ENSBodyRow(label: "Radius",      value: "696,000 km")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
        .navigationTitle("Sun")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(stops: [
                .init(color: .yellow.opacity(0.5), location: 0.0),
                .init(color: .yellow.opacity(0.1), location: 0.9),
                //                .init(color: star.spectralClass.color, location: -0.1),
            ], startPoint: .topTrailing, endPoint: .bottomLeading)
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
//        .preferredColorScheme(.dark)
        .task(id: "\(lat),\(lon),\(state.observationDate)") {
            await weather.fetch(latitude: lat, longitude: lon, date: state.observationDate)
        }
    }
}

// MARK: - Shared card / row components

struct ENSBodyCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.bottom, 6)
            VStack(spacing: 0) { content() }
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.08), lineWidth: 0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ENSBodyRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.callout).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        Divider().opacity(0.3).padding(.horizontal, 16)
    }
}

// MARK: - Angle helpers

extension Angle {
    var hmsString: String {
        let t = radians * (12.0 / Double.pi) * 3600
        let h = Int(t / 3600)
        let m = Int(t.truncatingRemainder(dividingBy: 3600) / 60)
        let s = t.truncatingRemainder(dividingBy: 60)
        return String(format: "%02dh %02dm %05.2fs", h, m, s)
    }
    var dmsString: String {
        let d = degrees; let sign = d >= 0 ? "+" : "-"
        let a = Swift.abs(d); let dd = Int(a)
        let mm = Int((a - Double(dd)) * 60)
        let ss = (a - Double(dd) - Double(mm) / 60) * 3600
        return String(format: "%@%02d° %02d′ %05.2f″", sign, dd, mm, ss)
    }
}

// MARK: - Date time helper

extension Date {
    var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: self)
    }
}

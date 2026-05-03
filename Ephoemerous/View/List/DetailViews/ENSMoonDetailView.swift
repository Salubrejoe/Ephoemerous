import SwiftUI

struct ENSMoonDetailView: View {
    @Environment(EAppState.self) var state
    private let weather = EWeatherService.shared
    private var moonData: (ra: Double, dec: Double, fraction: Double) {
        let (_, ra, dec) = EMoonPosition.vector(for: state.observationDate, siderealOffset: state.precessedSiderealOffset)
        let fraction = EMoonPosition.illuminatedFraction(for: state.observationDate)
        return (ra, dec, fraction)
    }
    private var lat: Double { state.origin.latitude.degrees }
    private var lon: Double { state.origin.longitude.degrees }
    private let accent = Color(red: 0.75, green: 0.82, blue: 1.0)
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private var phaseName: String {
        switch moonData.fraction {
        case ..<AstroConstants.phaseNewMoon:        return Strings.MoonPhase.newMoon
        case ..<AstroConstants.phaseWaxingCrescent: return Strings.MoonPhase.waxingCrescent
        case ..<AstroConstants.phaseFirstQuarter:   return Strings.MoonPhase.firstQuarter
        case ..<AstroConstants.phaseWaxingGibbous:  return Strings.MoonPhase.waxingGibbous
        case ..<AstroConstants.phaseFullMoon:       return Strings.MoonPhase.fullMoon
        case ..<AstroConstants.phaseWaningGibbous:  return Strings.MoonPhase.waningGibbous
        case ..<AstroConstants.phaseLastQuarter:    return Strings.MoonPhase.lastQuarter
        case ..<AstroConstants.phaseWaningCrescent: return Strings.MoonPhase.waningCrescent
        default: return Strings.MoonPhase.unknown
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                
                Text("Selene")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.leading, 4)
                HStack {
                    HStack(spacing: 8) {
                        Image(symbol: .rightAscension)
                        Text("\(String(format: "%.2fh", moonData.ra / AstroConstants.degreesPerHour))")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(.regularMaterial)
                    )
                    HStack(spacing: 8) {
                        Image(symbol: .declination)
                        Text("\(String(format: "%.2fh", moonData.dec / AstroConstants.degreesPerHour))")
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
                        label: "Phase",
                        value: phaseName,
                        accent: accent,
                        symbol: .calendar
                    )
                    ENSTile(
                        label: "Illumination",
                        value: String(format: "%.1f%%", moonData.fraction * 100),
                        accent: accent,
                        symbol: .calendar
                    )
                    ENSTile(
                        label: "Diameter",
                        value: "3,474 km",
                        accent: accent,
                        symbol: .calendar
                    )
                    ENSTile(
                        label: "Distance",
                        value: "~384,400 km",
                        accent: accent,
                        symbol: .calendar
                    )
                    ENSTile(
                        label: "Orbital Period",
                        value: "27.3 days",
                        accent: accent,
                        symbol: .calendar
                    )
                }
                ENSMoonEventsGrid(weather: weather, phaseName: phaseName, accent: accent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
//        .navigationTitle("Moon")
//        .navigationBarTitleDisplayMode(.large)
        .task(id: "\(lat),\(lon),\(state.observationDate)") {
            await weather.fetch(latitude: lat, longitude: lon, date: state.observationDate)
        }
    }
}

private struct ENSMoonEventsGrid: View {
    let weather: EWeatherService
    let phaseName: String
    let accent: Color
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        if weather.isLoading {
            ENSTile(label: "Events", value: "Fetching…", accent: accent,
                    symbol: .calendar)
        } else if let e = weather.moonEvents {
            LazyVGrid(columns: cols, spacing: 12) {
                let name = e.phaseLabel.isEmpty ? phaseName : e.phaseLabel
                ENSTile(label: "Phase Label", value: "\(e.phaseEmoji) \(name)", accent: accent,
                        symbol: .calendar)
                if let rise = e.moonrise { ENSTile(label: "Moonrise", value: rise.timeString, accent: accent,
                                                   symbol: .calendar) }
                if let set  = e.moonset  { ENSTile(label: "Moonset",  value: set.timeString,  accent: accent,
                                                   symbol: .calendar) }
            }
        } else if let err = weather.error {
            ENSTile(label: "Error", value: err, accent: accent,
                    symbol: .calendar)
        } else {
            ENSTile(label: "Phase", value: phaseName, accent: accent,
                    symbol: .calendar)
        }
    }
}

import SwiftUI

// MARK: - EMoonDetailView

struct EMoonDetailView: View {
    @Environment(EAppState.self) var state
    private let weather = EWeatherService.shared

    private var moonData: (ra: Double, dec: Double, fraction: Double) {
        let (_, ra, dec) = EMoonPosition.vector(
            for: state.observationDate,
            siderealOffset: state.precessedSiderealOffset
        )
        let fraction = EMoonPosition.illuminatedFraction(for: state.observationDate)
        return (ra, dec, fraction)
    }

    private var ra:  Angle { .degrees(moonData.ra) }
    private var dec: Angle { .degrees(moonData.dec) }
    private var lat: Double { state.origin.latitude.degrees }
    private var lon: Double { state.origin.longitude.degrees }

    private let accent = Color(red: 0.75, green: 0.82, blue: 1.0)

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
        default:                                    return Strings.MoonPhase.unknown
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EDetailSubtitle(text: String(format: "%.1f%% illuminated  384,400 km", moonData.fraction * 100))
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
        .navigationTitle("Selene")
        .navigationBarTitleDisplayMode(.large)
        .task(id: "\(lat),\(lon),\(state.observationDate)") {
            await weather.fetch(latitude: lat, longitude: lon, date: state.observationDate)
        }
    }

    private var eventsSection: some View {
        Group {
            EDetailSectionLabel(text: "Tonight")
            MoonEventsTimeline(weather: weather, phaseName: phaseName)
                .padding(.bottom, 28)
        }
    }

    private var coordinatesSection: some View {
        Group {
            EDetailSectionLabel(text: "Equatorial coordinates")
            ECoordinateDials(ra: ra, dec: dec, accent: accent)
                .padding(.bottom, 28)
        }
    }

    private var physicalSection: some View {
        Group {
            EDetailSectionLabel(text: "Physical")
            EDetailPhysicalRow(label: "Illumination",   value: String(format: "%.1f%%", moonData.fraction * 100), isLast: false)
            EDetailPhysicalRow(label: "Distance",       value: "~384,400 km",  isLast: false)
            EDetailPhysicalRow(label: "Diameter",       value: "3,474 km",     isLast: false)
            EDetailPhysicalRow(label: "Orbital period", value: "27.3 days",    isLast: true)
        }
    }
}

// MARK: - Moon events timeline

private struct MoonEventsTimeline: View {
    let weather: EWeatherService
    let phaseName: String

    var body: some View {
        if weather.isLoading {
            Text("Fetching...")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else if let e = weather.moonEvents {
            VStack(alignment: .leading, spacing: 0) {
                let wkPhase = e.phaseLabel.isEmpty ? phaseName : e.phaseLabel
                let wkEmoji = e.phaseEmoji
                if let rise = e.moonrise {
                    MoonEventRow(name: "Moonrise", emoji: nil,                                 time: rise, style: .rise,  isLast: false)
                }
                MoonEventRow(    name: wkPhase,    emoji: wkEmoji.isEmpty ? nil : wkEmoji,      time: nil,  style: .phase, isLast: e.moonset == nil)
                if let set = e.moonset {
                    MoonEventRow(name: "Moonset",  emoji: nil,                                 time: set,  style: .set,   isLast: true)
                }
            }
        } else if let err = weather.error {
            Text(err)
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            Text(phaseName)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MoonEventRow: View {
    enum RowStyle { case rise, phase, set }

    let name:  String
    let emoji: String?
    let time:  Date?
    let style: RowStyle
    let isLast: Bool

    private let moonAccent = Color(red: 0.75, green: 0.82, blue: 1.0)

    private var dotColor: Color {
        style == .phase ? moonAccent.opacity(0.4) : moonAccent
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
                    if style == .phase {
                        Circle()
                            .fill(moonAccent.opacity(0.12))
                            .frame(width: 16, height: 16)
                    }
                    Circle()
                        .fill(dotColor)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 16, height: 44)

            if let e = emoji { Text(e).font(.callout) }
            Text(name)
                .font(.callout)
                .foregroundStyle(style == .phase ? .secondary : .primary)
            Spacer()
            if let t = time {
                Text(t.timeString)
                    .font(.callout)
                    .monospacedDigit()
                    .fontDesign(.serif)
                    .foregroundStyle(style == .phase ? .secondary : .primary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EMoonDetailView()
    }
    .environment(EAppState())
}

import SwiftUI

struct ENSMoonDetailView: View {
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

    private var lat: Double { state.origin.latitude.degrees }
    private var lon: Double { state.origin.longitude.degrees }

    private var calculatedPhaseName: String {
        let f = moonData.fraction
        switch f {
        case ..<0.02:  return "New Moon"
        case ..<0.24:  return "Waxing Crescent"
        case ..<0.26:  return "First Quarter"
        case ..<0.49:  return "Waxing Gibbous"
        case ..<0.51:  return "Full Moon"
        case ..<0.74:  return "Waning Gibbous"
        case ..<0.76:  return "Last Quarter"
        case ..<0.98:  return "Waning Crescent"
        default:       return "New Moon"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // ── Hero — live phase disc ─────────────────────────────────
                let fraction = moonData.fraction
                let base: CGFloat = 50
//                ZStack {
//                    Circle()
//                        .fill(RadialGradient(
//                            colors: [.white.opacity(0.2 * fraction), .clear],
//                            center: .center, startRadius: 0, endRadius: 90))
//                        .frame(width: 180, height: 180)
//                    ZStack {
//                        Circle().fill(Color.gray.opacity(0.55))
//                        let shift = base * CGFloat(1.0 - 2.0 * fraction)
//                        Circle()
//                            .fill(Color.white.opacity(0.92))
//                            .frame(width: base * 2, height: base * 2)
//                            .offset(x: shift)
//                            .clipShape(Circle())
//                    }
//                    .frame(width: base * 2, height: base * 2)
//                    .clipShape(Circle())
//                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
//                }
//                .padding(.top, 8)

                // ── Moon Events ───────────────────────────────────────────
                ENSBodyCard(title: "Moon Events") {
                    if weather.isLoading {
                        ENSBodyRow(label: "Fetching…", value: "")
                    } else if let e = weather.moonEvents {
                        let phaseName = e.phaseLabel.isEmpty ? calculatedPhaseName : e.phaseLabel
                        ENSBodyRow(label: "Phase", value: "\(e.phaseEmoji) \(phaseName)")
                        if let rise = e.moonrise { ENSBodyRow(label: "Moonrise", value: rise.timeString) }
                        if let set  = e.moonset  { ENSBodyRow(label: "Moonset",  value: set.timeString)  }
                    } else if let err = weather.error {
                        ENSBodyRow(label: "Error", value: err)
                    } else {
                        ENSBodyRow(label: "Phase", value: calculatedPhaseName)
                    }
                }

                ENSBodyCard(title: "Phase") {
                    ENSBodyRow(label: "Illumination",
                               value: String(format: "%.1f%%", fraction * 100))
                }

                ENSBodyCard(title: "Coordinates") {
                    ENSBodyRow(label: "Right Ascension",
                               value: String(format: "%.2fh", moonData.ra / 15.0))
                    ENSBodyRow(label: "Declination",
                               value: String(format: "%+.2f°", moonData.dec))
                }

                ENSBodyCard(title: "Physical") {
                    ENSBodyRow(label: "Type",     value: "Natural satellite")
                    ENSBodyRow(label: "Diameter", value: "3,474 km")
                    ENSBodyRow(label: "Distance", value: "~384,400 km")
                    ENSBodyRow(label: "Period",   value: "27.3 days")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
        .navigationTitle("Moon")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(lat),\(lon),\(state.observationDate)") {
            await weather.fetch(latitude: lat, longitude: lon, date: state.observationDate)
        }
    }
}

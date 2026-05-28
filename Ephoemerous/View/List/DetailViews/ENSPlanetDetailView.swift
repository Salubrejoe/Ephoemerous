import SwiftUI

struct ENSPlanetDetailView: View {
    @Environment(EAppState.self) var state
    let planet: EPlanet

    private var position: (ra: Double, dec: Double)? {
        let results = EPlanetPosition.allVectors(
            for: state.observationDate,
            siderealOffset: state.precessedSiderealOffset
        )
        guard let match = results.first(where: { $0.planet.name == planet.name }) else { return nil }
        return (match.ra, match.dec)
    }

    private var ra:  Angle { position.map { .degrees($0.ra)  } ?? .zero }
    private var dec: Angle { position.map { .degrees($0.dec) } ?? .zero }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:    planet.name,
                subtitle: planet.mythology,
                accent:   planet.color,
                icon:     { Text(planet.astronomicalGlyph) },
                onShare:  {},
                onDismiss: { state.dismissDetail() }
            )
            RememberButton(obj: .planet(planet))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
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
        }
    }

    private var coordinatesSection: some View {
        Group {
            EDetailSectionLabel(text: "Equatorial coordinates")
            if position != nil {
                ECoordinateDials(ra: ra, dec: dec, accent: planet.color)
                    .padding(.bottom, 28)
            } else {
                Text("Position unavailable")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 28)
            }
        }
    }

    private var physicalSection: some View {
        Group {
            EDetailSectionLabel(text: "Physical")
            PlanetPhysicalRows(planet: planet)
        }
    }
}

// MARK: - Physical rows

private struct PlanetPhysicalRows: View {
    let planet: EPlanet

    private struct Facts {
        let diameter: String
        let distance: String
        let period:   String
    }

    private static let facts: [String: Facts] = [
        Strings.Planets.mercury: Facts(diameter: "4,879 km",    distance: "0.39 AU",  period: "88 days"),
        Strings.Planets.venus:   Facts(diameter: "12,104 km",   distance: "0.72 AU",  period: "225 days"),
        Strings.Planets.mars:    Facts(diameter: "6,779 km",    distance: "1.52 AU",  period: "687 days"),
        Strings.Planets.jupiter: Facts(diameter: "139,820 km",  distance: "5.20 AU",  period: "11.9 yr"),
        Strings.Planets.saturn:  Facts(diameter: "116,460 km",  distance: "9.58 AU",  period: "29.5 yr"),
        Strings.Planets.uranus:  Facts(diameter: "50,724 km",   distance: "19.2 AU",  period: "84.0 yr"),
        Strings.Planets.neptune: Facts(diameter: "49,244 km",   distance: "30.1 AU",  period: "164.8 yr"),
    ]

    var body: some View {
        EDetailPhysicalRow(
            label: "Mean magnitude",
            value: String(format: "%.1f", planet.baseMagnitude),
            isLast: false
        )
        if let f = Self.facts[planet.name] {
            EDetailPhysicalRow(label: "Diameter", value: f.diameter, isLast: false)
            EDetailPhysicalRow(label: "Distance", value: f.distance, isLast: false)
            EDetailPhysicalRow(label: "Period",   value: f.period,   isLast: true)
        } else {
            EDetailPhysicalRow(label: "Mean magnitude",
                               value: String(format: "%.1f", planet.baseMagnitude),
                               isLast: true)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ENSPlanetDetailView(planet: .mars)
    }
    .environment(EAppState())
}

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

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // ── Hero ──────────────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [planet.color.opacity(0.35), .clear],
                            center: .center, startRadius: 0, endRadius: 90))
                        .frame(width: 180, height: 180)
                    Circle()
                        .fill(RadialGradient(
                            colors: [.white.opacity(0.9), planet.color],
                            center: .center, startRadius: 0, endRadius: 22))
                        .frame(width: 44, height: 44)
                        .shadow(color: planet.color, radius: 12)
                }
                .padding(.top, 8)

                // ── Coordinates ───────────────────────────────────────────
                ENSBodyCard(title: "Coordinates") {
                    if let pos = position {
                        ENSBodyRow(label: "Right Ascension",
                                   value: String(format: "%.2fh", pos.ra / 15.0))
                        ENSBodyRow(label: "Declination",
                                   value: String(format: "%+.2f°", pos.dec))
                    } else {
                        ENSBodyRow(label: "Unavailable", value: "")
                    }
                }

                // ── Physical ──────────────────────────────────────────────
                ENSBodyCard(title: "Physical") {
                    ENSBodyRow(label: "Type",           value: "Solar system planet")
                    ENSBodyRow(label: "Mean magnitude", value: String(format: "%.1f", planet.baseMagnitude))
                    if let facts = EPlanetFacts.facts[planet.name] {
                        ENSBodyRow(label: "Diameter",   value: facts.diameter)
                        ENSBodyRow(label: "Distance",   value: facts.distance)
                        ENSBodyRow(label: "Period",     value: facts.period)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle(planet.name)
        .navigationBarTitleDisplayMode(.large)
        .background(.black)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Static physical facts

private enum EPlanetFacts {
    struct Facts {
        let diameter: String
        let distance: String
        let period:   String
    }

    static let facts: [String: Facts] = [
        "Mercury": Facts(diameter: "4,879 km",     distance: "0.39 AU",  period: "88 days"),
        "Venus":   Facts(diameter: "12,104 km",    distance: "0.72 AU",  period: "225 days"),
        "Mars":    Facts(diameter: "6,779 km",      distance: "1.52 AU",  period: "687 days"),
        "Jupiter": Facts(diameter: "139,820 km",   distance: "5.20 AU",  period: "11.9 yr"),
        "Saturn":  Facts(diameter: "116,460 km",   distance: "9.58 AU",  period: "29.5 yr"),
        "Uranus":  Facts(diameter: "50,724 km",    distance: "19.2 AU",  period: "84.0 yr"),
        "Neptune": Facts(diameter: "49,244 km",    distance: "30.1 AU",  period: "164.8 yr"),
    ]
}

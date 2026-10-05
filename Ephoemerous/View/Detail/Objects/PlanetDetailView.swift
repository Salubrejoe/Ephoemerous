import SwiftUI
import LoreKit

// MARK: - PlanetDetailView
// A planet's place card (see `PlaceSheet`):
//
//   [        DISTANCE  (wide)        ]   today, between nearest and farthest
//   [ RISE & SET   ][  BRIGHTNESS    ]
//   [          ORBIT  (wide)         ]   it and the Earth round the Sun, today
//   [  POSITION    ][     SIZE       ]
//
// Find in the sky at its foot; no Remember (planets aren't favourited).
struct PlanetDetailView: View {
    @Environment(AppState.self) var state
    let planet: Planet

    var body: some View {
        PlaceSheet(object:   .planet(planet),
                   title:    planet.displayName,
                   subtitle: planet.mythology) {
            tiles
        } actions: {
            PlaceActions(object: .planet(planet), remember: false)
        }
    }

    @ViewBuilder
    private var tiles: some View {
        let date   = state.observationDate
        let vector = PlanetPosition.allVectors(for: date, siderealOffset: state.precessedSiderealOffset)
            .first { $0.planet.name == planet.name }
        let status = SkyStatus.cached(object: .planet(planet), date: date, observer: state.placeObserver)
        let path   = StarDayPath(object: .planet(planet), around: date, observer: state.placeObserver)
        if let facts = BodyFacts.planet(planet) {
            DetailGridLayout(rows: [1, 2, 1, 2]) {
                BodyDistanceTile(currentKm: PlanetPosition.distanceAU(planet, date: date).map { $0 * BodyFacts.kmPerAU },
                                 range:     facts.nearestKm ... facts.farthestKm)
                RiseSetTile(status: status, path: path)
                BrightnessTile(magnitude: planet.baseMagnitude)
                OrbitTile(planet: planet, facts: facts, date: date)
                PositionTile(raHours: (vector?.ra ?? 0) / 15, decDegrees: vector?.dec ?? 0)
                SizeTile(facts: facts, color: Artist.shared.planetGradient(planet).top)
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { PlanetDetailView(planet: .mars) }
        .environment(AppState())
}
#endif

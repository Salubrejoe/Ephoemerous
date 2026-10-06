import SwiftUI
import LoreKit

// MARK: - SunDetailView
// The Sun's place card (see `PlaceSheet`):
//
//   [        DISTANCE  (wide)        ]   today, between perihelion and aphelion
//   [ RISE & SET   ][   DAYLIGHT     ]
//   [          TYPE  (wide)          ]   the HR diagram, the Sun in the spotlight
//   [  POSITION    ][     SIZE       ]
//
// No Remember (the Sun isn't favourited) and no Find — no one should go
// hunting the Sun through a phone.
struct SunDetailView: View {
    @Environment(AppState.self) var state

    var body: some View {
        PlaceSheet(object:   .sun,
                   title:    Strings.Bodies.sun,
                   subtitle: String(localized: "Our star · a yellow dwarf")) {
            tiles
        } actions: {
            EmptyView()
        }
    }

    private var tiles: some View {
        let date   = state.observationDate
        let lambda = SunPosition.eclipticLongitude(for: date)
        let coords = SunPosition.equatorialCoords(lambda: lambda)
        let status = SkyStatus.cached(object: .sun, date: date, observer: state.placeObserver)
        let path   = StarDayPath(object: .sun, around: date, observer: state.placeObserver)
        let facts  = BodyFacts.sun
        return DetailGridLayout(rows: [1, 2, 1, 2]) {
            BodyDistanceTile(currentKm: PlanetPosition.sunDistanceAU(date: date) * BodyFacts.kmPerAU,
                             range:     facts.nearestKm ... facts.farthestKm)
            RiseSetTile(status: status, path: path)
            DaylightTile(path: path)
            DetailCard(title: String(localized: "Type"), symbol: "thermometer.medium") {
                VStack(alignment: .leading, spacing: 4) {
                    MiniHRDiagram(star: nil).frame(maxHeight: .infinity)
                    Text("A G-type main-sequence star — an ordinary one")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            PositionTile(raHours: coords.ra.degrees / 15, decDegrees: coords.dec.degrees)
            SizeTile(facts: facts, color: Artist.shared.palette.sun.bottom)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { SunDetailView() }
        .environment(AppState())
}
#endif

import SwiftUI
import LoreKit

// MARK: - MoonDetailView
// The Moon's place card (see `PlaceSheet`):
//
//   [          PHASE  (wide)         ]   tonight's face, % lit, full/new next
//   [ RISE & SET   ][   DISTANCE     ]   today, between perigee and apogee
//   [  POSITION    ][     SIZE       ]
//
// Find in the sky at its foot; no Remember (the Moon isn't favourited).
struct MoonDetailView: View {
    @Environment(AppState.self) var state

    private var phase: LunarPhase {
        MoonPosition.phase(for: state.observationDate, latitude: state.origin.latitude)
    }

    var body: some View {
        PlaceSheet(object:   .moon,
                   title:    Strings.Bodies.moon,
                   subtitle: phase.name) {
            tiles
        } actions: {
            PlaceActionRow { FindAction(solo: true) }
        }
    }

    private var tiles: some View {
        let date   = state.observationDate
        let (_, ra, dec) = MoonPosition.vector(for: date, siderealOffset: state.precessedSiderealOffset)
        let status = SkyStatus.cached(object: .moon, date: date, observer: state.placeObserver)
        let path   = StarDayPath(object: .moon, around: date, observer: state.placeObserver)
        let facts  = BodyFacts.moon
        return DetailGridLayout(rows: [1, 2, 2]) {
            MoonPhaseTile(phase: phase, fraction: MoonPosition.illuminatedFraction(for: date), date: date)
            RiseSetTile(status: status, path: path)
            BodyDistanceTile(currentKm: MoonPosition.distanceKm(for: date),
                             range:     facts.nearestKm ... facts.farthestKm)
            PositionTile(raHours: ra / 15, decDegrees: dec)
            SizeTile(facts: facts, color: Artist.shared.poiStyle(for: .moon).gradientTop)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { MoonDetailView() }
        .environment(AppState())
}
#endif

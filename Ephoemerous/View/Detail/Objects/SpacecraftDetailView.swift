import SwiftUI
import LoreKit

// MARK: - SpacecraftDetailView
// ISS / Hubble / Tiangong / Webb, as a place card (see `PlaceSheet`):
//
//   [   VISIBLE PASSES  (wide)       ]   the craft you can see — tap one to
//                                         roll the sky to its peak
//   [   DISTANCE        (wide)       ]   Webb instead: a million-plus km out
//   [   RIGHT NOW       (wide)       ]   where it is and how it's moving
//
// The toolbar's leading corner is "back to now" — no postcard: a craft's
// place is only true for a minute. Find in the sky at the foot; no
// Remember. While the observation is live the facts tick every second.
//
// All wording lives in `SpacecraftFacts`; this view only lays it out.
struct SpacecraftDetailView: View {
    @Environment(AppState.self) var state
    let craft: Spacecraft

    private var tracker: SpacecraftTracker { .shared }

    var body: some View {
        PlaceSheet(object:   .spacecraft(craft),
                   title:    craft.displayName,
                   subtitle: craft.portrait,
                   leading:  .button(.resetClock, { state.commitPickedObservationDate(.now) })) {
            if state.isObservationLive {
                TimelineView(.periodic(from: .now, by: 1)) { tick in tiles(at: tick.date) }
            } else {
                tiles(at: nil)
            }
        } actions: {
            PlaceActionRow { FindAction(solo: true) }
        }
        .task(id: passRequest) { tracker.updatePasses(for: state.placeObserver, from: state.observationDate) }
    }

    /// Facts for the moment the craft is drawn at — the wall clock while
    /// the observation is live, else the sky's frozen moment.
    private func tiles(at liveDate: Date?) -> some View {
        let facts = SpacecraftFacts(craft:    craft,
                                    date:     liveDate ?? state.renderedObservationDate,
                                    observer: state.placeObserver)
        return DetailGridLayout(rows: [1, 1]) {
            if craft.isInEarthOrbit {
                PassesTile(passes: facts.visiblePasses) { pass in
                    state.commitPickedObservationDate(pass.peak.date)
                }
            } else {
                BodyDistanceTile(currentKm: tracker.rangeKm(of: craft, at: facts.date, from: state.placeObserver))
            }
            FactsTile(title:  String(localized: "Right now"),
                      symbol: "location.north.circle",
                      stats:  facts.stats)
        }
    }

    /// Passes are re-predicted when where, roughly when, or the orbit
    /// itself changes — the tracker dedupes anything finer.
    private var passRequest: PassRequest {
        PassRequest(latitude:  state.origin.latitude.degrees,
                    longitude: state.origin.longitude.degrees,
                    hour:      Int(state.observationDate.timeIntervalSince1970 / 3_600),
                    epoch:     tracker.orbits[craft]?.elements.epoch)
    }

    private struct PassRequest: Equatable {
        let latitude:  Double
        let longitude: Double
        let hour:      Int
        let epoch:     Date?
    }
}

#if DEBUG
#Preview {
    NavigationStack { SpacecraftDetailView(craft: .iss) }
        .environment(AppState())
}
#endif

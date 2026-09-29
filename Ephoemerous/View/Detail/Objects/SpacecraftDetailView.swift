import SwiftUI
import LoreKit

// MARK: - SpacecraftDetailView
// ISS / Hubble / Webb. The header, then — for the two craft you can see
// with your own eyes — the next visible passes over the observer, each one
// a tap away: tapping a pass rolls the sky to its peak, where the badge is
// sitting high overhead. Below, where the craft is at the observation
// moment. No Remember and no postcard: a spacecraft's place is only true
// for a minute, so neither would keep.
//
// All wording lives in `SpacecraftFacts`; this view only lays it out.
struct SpacecraftDetailView: View {
    @Environment(AppState.self) var state
    @Environment(\.detailCollapsed) private var collapsed
    let craft: Spacecraft

    private var tracker: SpacecraftTracker { .shared }
    private var accent:  Color { Artist.shared.spacecraftGradient.bottom }

    private var observer: SatelliteSky.Observer {
        SatelliteSky.Observer(latitude:  state.origin.latitude.radians,
                              longitude: state.origin.longitude.radians)
    }

    /// Facts for the moment the craft is drawn at — the wall clock while
    /// the observation is live, else the sky's frozen moment.
    private func facts(at liveDate: Date?) -> SpacecraftFacts {
        SpacecraftFacts(craft:    craft,
                        date:     liveDate ?? state.renderedObservationDate,
                        observer: observer)
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:         craft.displayName,
                subtitle:      craft.portrait,
                accent:        accent,
                icon:          { POILabelView(category: .spacecraft(craft), text: "") },
                leadingSymbol: .resetClock,
                onLeading:     returnToNow,
                onDismiss:     { state.dismissDetail() }
            )

            if !collapsed {
                if state.isObservationLive {
                    TimelineView(.periodic(from: .now, by: 1)) { tick in
                        factList(facts(at: tick.date))
                    }
                } else {
                    factList(facts(at: nil))
                }
            }
            Spacer(minLength: 0)
        }
        .task(id: passRequest) { tracker.updatePasses(for: observer, from: state.observationDate) }
    }

    // MARK: Sections

    private func factList(_ facts: SpacecraftFacts) -> some View {
        List {
            if craft.isInEarthOrbit { passesSection(facts) }
            Section { statRows(facts) }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func passesSection(_ facts: SpacecraftFacts) -> some View {
        let passes = facts.visiblePasses
        Section(String(localized: "Visible passes")) {
            if passes.isEmpty {
                Text(String(localized: "None in the next few days"))
                    .foregroundStyle(.secondary)
            }
            ForEach(passes) { pass in
                Button { jump(to: pass) } label: { passRow(pass) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func passRow(_ pass: SatellitePass) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(SpacecraftFacts.whenText(pass))
                .foregroundStyle(.primary)
            Text(SpacecraftFacts.summaryText(pass))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private func statRows(_ facts: SpacecraftFacts) -> some View {
        ForEach(facts.stats) { stat in
            LabeledContent {
                Text(stat.value)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            } label: {
                Text(stat.label)
            }
        }
    }

    // MARK: Actions

    /// Roll the sky to the pass's peak — the craft lands high overhead,
    /// badge and all, and the stats below describe that moment.
    private func jump(to pass: SatellitePass) {
        state.commitPickedObservationDate(pass.peak.date)
    }

    private func returnToNow() {
        state.commitPickedObservationDate(.now)
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
    NavigationStack {
        SpacecraftDetailView(craft: .iss)
    }
    .environment(AppState())
}
#endif

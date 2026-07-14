import SwiftUI
import LoreKit

// MARK: - SearchSheet
// Apple-Maps-flavoured search surface that opens from the bottom-
// right search icon in MainView. Layout:
//
//   ┌────────────────────────────────────────────────────────┐
//   │  🔍 Search a star, constellation…         ⓧ       ✕   │
//   ├────────────────────────────────────────────────────────┤
//   │  FAVOURITES                                            │
//   │  [Star] [Const] [Star] [Const] [Star]  →               │
//   ├────────────────────────────────────────────────────────┤
//   │  (when search text is non-empty)                       │
//   │  RESULTS                                               │
//   │   • Sun                                                │
//   │   • Sirius                                             │
//   │   • …                                                  │
//   └────────────────────────────────────────────────────────┘
//
// The horizontal-scroll favourites row uses the shared
// `StarCard` / `ConstellationCard` from
// `View/Cards/EFavouriteCards.swift`. Tapping any favourite card
// — or any result row — focuses the canvas on that object and
// dismisses the sheet; the existing `detailDestination` flow then
// brings up the matching detail card.
struct SearchSheet: View {

    @Environment(EAppState.self) private var state
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool
    @State private var detent: PresentationDetent = Self.barDetent

    /// Full-screen Hertzsprung–Russell diagram. Presented from THIS
    /// sheet (not MainView) because the search sheet is always up — a
    /// cover hung off the root would fight the active presentation.
    @State private var showHRDiagram = false

    /// Resting "search bar only" detent — the persistent always-present
    /// state, just tall enough for the field + grabber. Drag up (or focus
    /// the field) to reveal favourites, then results.
    private static let barDetent: PresentationDetent = .height(72)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Pure search — the camera controls moved to the
                // bottom-trailing capsule (CameraClusterCapsule), so the
                // bar has exactly one job.
                searchHeader

                // Hertzsprung–Russell diagram — full-screen star chart.
//                hrButton
            }
                .padding(.leading, 12)
                .padding(.trailing, 14)
                .padding(.top, 18)
                .padding(.bottom, 18)

            if searchText.isEmpty && detent != Self.barDetent {
                // Idle browse state: favourites scroll + recents list,
                // Apple-Maps style. Scrolls as one when the sheet is
                // dragged up to medium / large.
                
                
//                Text(String(localized: "REMEMBERED"))
//                    .font(.default.weight(.semibold))
//                    .foregroundStyle(.gray)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.leading, 32)
//                    .padding(.top, 24)
                favouritesSection
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                
                List {
                    Section("RECENTS") {
                        if !state.recentObjects.isEmpty {
                            ForEach(Array(state.recentObjects.enumerated()), id: \.element.id) { idx, obj in
                                Button { open(obj) } label: {
                                    Text(obj.displayName)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
//                .listStyle(.plain)
            } else {
                resultsList
            }
        }
        // Persistent Apple-Maps-style bottom sheet: never fully
        // dismissed (it's the home of search) — swiping down parks it at
        // the bar-only detent instead. Selecting an object is what hides
        // it: `detailDestination` flips non-nil and MainView's derived
        // binding dismisses this in favour of the detail sheet.
        .presentationDetents([Self.barDetent, .medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .interactiveDismissDisabled(true)
        // Focusing the field (keyboard up) expands the sheet so results
        // aren't buried under the keyboard at the bar detent.
        .onChange(of: searchFocused) { _, focused in
            if focused, detent == Self.barDetent { detent = .large }
        }
        // Typing from a parked sheet should also lift it.
        .onChange(of: searchText) { _, text in
            if !text.isEmpty, detent == Self.barDetent { detent = .medium }
        }
        .fullScreenCover(isPresented: $showHRDiagram) {
            EHRDiagramView()
        }
        .alert("Return to your location?",
               isPresented: Bindable(state)._compassReturnHomePrompt) {
            Button("Cancel", role: .cancel) { }
            Button("Switch to Here") { state.confirmReturnHomeAndEngageCompass() }
        } message: {
            Text(String(localized: "Compass mode orients the sky from where you're standing. Move the map back to your location?"))
        }
    }

    // MARK: Header

    // Persistent sheet → no dismiss X. The capsule fills the width; the
    // trailing clear-button appears only while there's text to clear.
    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(symbol: .search)
            TextField(String(localized: "Search, remember..."), text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchFocused = false
                } label: {
                    Image(symbol: .xmarkCircleFill)
                }
                .buttonStyle(.plain)
            }
            
            
        }
//        .font(.callout)
        .padding(.horizontal, 18)
        .frame(height: 47)
        .glassEffect(.regular.interactive(), in: .containerRelative)
    }

    // MARK: Favourites scroll

    /// Star + Constellation favourites only — the two card species
    /// the user spec'd. Solar-system favourites are stored on
    /// `state.favourites` but don't have a card form yet (they're
    /// always present on the canvas anyway).
    private var favouriteCards: [ESkyObject] {
        state.favourites.filter {
            switch $0 {
            case .star, .constellation: return true
            default:                    return false
            }
        }
    }

    private var favouritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            if favouriteCards.isEmpty {
                Text("No favourites yet. Tap the heart on a star or constellation to add it.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(favouriteCards) { obj in
                            cardView(for: obj)
                                .onTapGesture { open(obj) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func cardView(for obj: ESkyObject) -> some View {
        switch obj {
        case .star(let s):          StarCard(star: s)
        case .constellation(let c): ConstellationCard(constellation: c)
        default:                    EmptyView()
        }
    }


    /// One recents row — icon + name + type, mirroring `resultRow` but
    /// laid out for the inset card (its own padding, no List chrome).
    private func recentRowBody(for obj: ESkyObject) -> some View {
        HStack(spacing: 12) {
            resultIcon(for: obj)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(obj.displayName)
                    .font(.callout)
                    .fontDesign(.serif)            // sky-object name → serif
                    .foregroundStyle(.primary)
                Text(typeLabel(obj))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical,   10)
        .contentShape(.rect)
    }

    // MARK: Results

    private var resultsList: some View {
        List {
            if !solarResults.isEmpty {
                Section("Solar system") {
                    ForEach(solarResults) { obj in
                        resultRow(for: obj)
                    }
                }
            }
            if !constellationResults.isEmpty {
                Section("Constellations") {
                    ForEach(constellationResults) { obj in
                        resultRow(for: obj)
                    }
                }
            }
            if !starResults.isEmpty {
                Section("Stars") {
                    ForEach(starResults) { obj in
                        resultRow(for: obj)
                    }
                }
            }
            if solarResults.isEmpty
                && constellationResults.isEmpty
                && starResults.isEmpty {
                Section {
                    Text("No matches for \"\(searchText)\".")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func resultRow(for obj: ESkyObject) -> some View {
        Button { open(obj) } label: {
            HStack(spacing: 12) {
                resultIcon(for: obj)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(obj.displayName)
                        .font(.callout)
                        .fontDesign(.serif)            // sky-object name → serif
                        .foregroundStyle(.primary)
                    Text(typeLabel(obj))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func resultIcon(for obj: ESkyObject) -> some View {
        switch obj {
        case .star(let s):
            POILabelView(category: .followedStar(s), text: "", labelStyle: .star)
//            POIBadgeView(category: .followedStar(s), size: 22)
        case .sun:
            POILabelView(category: .sun, text: "", labelStyle: .star)
//            POIBadgeView(category: .sun, size: 22)
        case .moon:
            POILabelView(category: .moon, text: "")
//            POIBadgeView(category: .moon, size: 22)
        case .planet(let p):
            POILabelView(category: .planet(p), text: "")
//            POIBadgeView(category: .planet(p), size: 22)
        case .constellation(let c):
            Image(symbol: EArtist.shared.constellationEntitySymbol(
                EArtist.shared.constellationEntity(of: c)
            ))
            .foregroundStyle(.secondary)
        }
    }

    private func typeLabel(_ obj: ESkyObject) -> String {
        switch obj {
        case .star(let s):          return String(localized: "Star · \(s.constellation.localizedName)")
        case .sun:                  return String(localized: "Solar system · Star")
        case .moon:                 return String(localized: "Solar system · Moon")
        case .planet:               return String(localized: "Solar system · Planet")
        case .constellation:        return String(localized: "Constellation")
        }
    }

    // MARK: Search execution

    private var query: String { searchText.lowercased() }

    private var solarResults: [ESkyObject] {
        let all: [ESkyObject] = [.sun, .moon] + EPlanet.all.map { .planet($0) }
        return all.filter { $0.searchTokens.contains(query) }
    }

    private var constellationResults: [ESkyObject] {
        EConstellation.allCases
            .filter { $0 != .none }
            .map    { ESkyObject.constellation($0) }
            .filter { $0.searchTokens.contains(query) }
            .sorted { $0.displayName < $1.displayName }
    }

    /// Hard cap the star list because there are ~hundreds of named
    /// stars and the list would otherwise wreck the sheet's
    /// scroll feel for a query like "a".
    private var starResults: [ESkyObject] {
        let matches = StarDatabase.shared.listableStars
            .filter { $0.name != "Unknown" }
            .map    { ESkyObject.star($0) }
            .filter { $0.searchTokens.contains(query) }
        return Array(matches.prefix(50))
    }

    // MARK: Actions

    /// Focus the canvas on `obj` (sets `detailDestination` and pans the
    /// camera). Setting `detailDestination` is what swaps this persistent
    /// search sheet out for the detail sheet — MainView's derived binding
    /// hides search the moment a selection exists. We just drop keyboard
    /// focus and reset the field so search returns clean on dismiss.
    private func open(_ obj: ESkyObject) {
        searchFocused = false
        searchText = ""
        state.focus(on: obj)
    }
}

#Preview {
    SearchSheet()
        .environment(EAppState())
}

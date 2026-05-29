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
    @Environment(\.dismiss)      private var dismiss
    @State private var searchText: String = ""
    /// Push-based navigation inside the sheet. Tapping a favourite
    /// card or a result row appends to the path; the pushed detail
    /// view's `dismiss()` (back chevron) pops back here — same flow
    /// as Apple Maps.
    @State private var path: [ESkyObject] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                searchHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                if searchText.isEmpty {
                    favouritesSection
                    Spacer(minLength: 0)
                } else {
                    resultsList
                }
            }
            .background(Color(.systemBackground))
            // System nav-bar is hidden — every pushed detail view
            // draws its own DetailHeader (with chevron-back / share
            // / X) so the chrome reads as one species across the
            // app, search-pushed or canvas-tapped.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ESkyObject.self) { obj in
                detailView(for: obj)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    /// Render the matching detail view for the pushed object. Each
    /// view's own `.onAppear` calls `state.panTo(_:)` so the canvas
    /// follows without us needing to call it here.
    @ViewBuilder
    private func detailView(for obj: ESkyObject) -> some View {
        switch obj {
        case .sun:                  ESunDetailView()
        case .moon:                 EMoonDetailView()
        case .star(let s):          EStarDetailView(star: s)
        case .planet(let p):        ENSPlanetDetailView(planet: p)
        case .constellation(let c): EConstellationDetailView(constellation: c)
        }
    }

    // MARK: Header

    private var searchHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search the sky…", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical,   10)
            .background(Color(.secondarySystemFill),
                        in: Capsule())

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.callout.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemFill), in: Circle())
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
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
            Text("Favourites")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.horizontal, 16)

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
                .frame(height: 100)
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
            POIBadgeView(category: .followedStar(s), size: 22)
        case .sun:
            POIBadgeView(category: .sun, size: 22)
        case .moon:
            POIBadgeView(category: .moon, size: 22)
        case .planet(let p):
            POIBadgeView(category: .planet(p), size: 22)
        case .constellation(let c):
            Image(systemName: EArtist.shared.constellationEntitySymbol(
                EArtist.shared.constellationEntity(of: c)
            ))
            .foregroundStyle(.secondary)
        }
    }

    private func typeLabel(_ obj: ESkyObject) -> String {
        switch obj {
        case .star(let s):          return "Star · \(s.constellation.fullName)"
        case .sun:                  return "Solar system · Star"
        case .moon:                 return "Solar system · Moon"
        case .planet:               return "Solar system · Planet"
        case .constellation:        return "Constellation"
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

    /// Push `obj`'s detail view onto the sheet's own nav stack. The
    /// pushed detail view's `.onAppear` calls `state.panTo(_:)` so
    /// the canvas behind follows; its back chevron (`dismiss()`)
    /// pops the stack and returns the user to the search results.
    private func open(_ obj: ESkyObject) {
        path.append(obj)
    }
}

#Preview {
    SearchSheet()
        .environment(EAppState())
}

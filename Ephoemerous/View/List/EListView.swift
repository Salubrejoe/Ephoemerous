import SwiftUI

// MARK: - Tab model
enum EListTab: String, CaseIterable, Identifiable {
    case solarSystem    = "Solar System"
    case constellations = "Constellations"
    case stars          = "Stars"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .solarSystem:    return "sun.and.horizon"
        case .constellations: return "sparkles"
        case .stars:          return "star"
        }
    }
}

// MARK: - Sort model
enum EStarSort: String, CaseIterable, Identifiable {
    case magnitude     = "Magnitude"
    case constellation = "Constellation"
    case name          = "Name"
    var id: String { rawValue }
}

// MARK: - Search Results
extension EListView {
    private var baseStars: [EStar] {
        StarDatabase.shared.workableStars.filter { $0.name != "Unknown" }
    }
    private var solarSystemResults: [ESkyObject] {
        let all: [ESkyObject] = [.sun, .moon] + EPlanet.all.map { .planet($0) }
        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter { $0.searchTokens.contains(q) }
    }
    private var constellationResults: [ESkyObject] {
        let all = EConstellation.allCases
            .filter { $0 != .none }
            .sorted { $0.fullName < $1.fullName }
            .map { ESkyObject.constellation($0) }
        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter { $0.searchTokens.contains(q) }
    }
    private var displayedStars: [EStar] {
        var result = baseStars.filter { $0.magnitude <= state.magnitudeFilter }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { ESkyObject.star($0).searchTokens.contains(q) }
        }
        result.sort { $0.magnitude < $1.magnitude }
        return result
    }
    private var recentDisplayed: [EStar] {
        state.recentStars.filter { $0.magnitude <= state.magnitudeFilter }
    }
}

// MARK: - Main list
struct EListView: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss
    @State private var searchText    = ""
    @State private var showSortSheet = false
    @State private var activeTab     = EListTab.solarSystem
    private let magnitudeRange = -2.0...8.0

    var body: some View {
        List {
            // Recent -- always on top regardless of tab
            if searchText.isEmpty && !recentDisplayed.isEmpty {
                Section {
                    ForEach(recentDisplayed) { star in
                        NavigationLink(value: ESkyObject.star(star)) { EStarRowView(star: star) }
                    }
                } header: { header(title: .recentlyViewed) }
            }

            // Tab content
            switch activeTab {
            case .solarSystem:
                Section {
                    ForEach(solarSystemResults) { obj in
                        NavigationLink(value: obj) { ESkyObjectRow(obj: obj) }
                    }
                } header: { header(title: .solarSystem) }

            case .constellations:
                Section {
                    ForEach(constellationResults) { obj in
                        NavigationLink(value: obj) { ESkyObjectRow(obj: obj) }
                    }
                } header: { header(title: .constellations) }

            case .stars:
                Section {
                    ForEach(displayedStars) { star in
                        NavigationLink(value: ESkyObject.star(star)) { EStarRowView(star: star) }
                    }
                } header: { header(title: .allStars) }
            }
        }
        .navigationDestination(for: ESkyObject.self) { obj in
            switch obj {
            case .star(let s):
                EStarDetailView(star: s)
                    .onAppear { state.recordViewed(s) }
            case .sun:                ENSSunDetailView()
            case .moon:               ENSMoonDetailView()
            case .planet(let p):      ENSPlanetDetailView(planet: p)
            case .constellation(let c): EConstellationDetailView(constellation: c)
            }
        }
        .searchable(text: $searchText, prompt: Strings.Prompts.searchBar)
        .onChange(of: searchText) {
            // If searching, jump to the tab most likely to have results
            guard !searchText.isEmpty else { return }
            if !displayedStars.isEmpty         { activeTab = .stars }
            else if !constellationResults.isEmpty { activeTab = .constellations }
            else if !solarSystemResults.isEmpty  { activeTab = .solarSystem }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if activeTab == .stars {
                    Button { showSortSheet = true } label: { Image(symbol: .sort) }
                }
            }
            ToolbarItem(placement: .principal) {
                Picker("", selection: $activeTab) {
                    ForEach(EListTab.allCases) { tab in
                        Image(systemName: tab.symbol).tag(tab)
                            .font(.footnote)
                    }
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: { Image(symbol: .xmark) }
            }
        }
        .bottomSheet(
            .sortNFilter,
            isPresented: $showSortSheet,
            content: {
                ESortFilterSheet(
                    magnitudeCap: Bindable(state).magnitudeFilter,
                    magnitudeRange: magnitudeRange,
                    starCount: displayedStars.count
                )
            }
        )
    }

    @ViewBuilder private func header(title: Strings.Titles) -> some View {
        Text(title.rawValue).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(nil)
    }
}

#Preview {
    NavigationStack { EListView() }.environment(EAppState())
}

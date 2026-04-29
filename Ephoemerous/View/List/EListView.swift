import SwiftUI

// MARK: - Tab model
enum EListTab: String, CaseIterable, Identifiable {
    case recents        = "Recents"
    case solarSystem    = "Solar System"
    case constellations = "Constellations"
    case stars          = "Stars"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .recents:        return "clock"
        case .solarSystem:    return "sun.and.horizon"
        case .constellations: return "sparkles"
        case .stars:          return "star"
        }
    }
}

// MARK: - Sort order
enum EStarSort: String, CaseIterable, Identifiable {
    case name          = "Alphabetically"
    case magnitude     = "By Magnitude"
    case constellation = "By Constellation"
    case spectralClass = "By Spectral Class"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .name:          return "textformat.abc"
        case .magnitude:     return "sparkle"
        case .constellation: return "map"
        case .spectralClass: return "thermometer.sun"
        }
    }
}

// MARK: - Computed results
extension EListView {

    private var isSearching: Bool { !searchText.isEmpty }

    private var showRecents: Bool { !isSearching && activeTab == .recents }
    private var showSolarSystem: Bool { isSearching || activeTab == .solarSystem }
    private var showConstellations: Bool { isSearching || activeTab == .constellations }
    private var showStars: Bool { isSearching || activeTab == .stars }

    private var solarSystemResults: [ESkyObject] {
        let all: [ESkyObject] = [.sun, .moon] + EPlanet.all.map { .planet($0) }
        guard isSearching else { return all }
        let q = searchText.lowercased()
        return all.filter { $0.searchTokens.contains(q) }
    }

    private var constellationResults: [ESkyObject] {
        let all = EConstellation.allCases
            .filter { $0 != .none }
            .sorted { $0.fullName < $1.fullName }
            .map { ESkyObject.constellation($0) }
        guard isSearching else { return all }
        let q = searchText.lowercased()
        return all.filter { $0.searchTokens.contains(q) }
    }

    private var displayedStars: [EStar] {
        var result = StarDatabase.shared.workableStars
            .filter { $0.name != "Unknown" && $0.magnitude <= state.magnitudeFilter }
        if isSearching {
            let q = searchText.lowercased()
            result = result.filter { ESkyObject.star($0).searchTokens.contains(q) }
        }
        switch sortOrder {
        case .name:          return result.sorted { $0.name < $1.name }
        case .magnitude:     return result.sorted { $0.magnitude < $1.magnitude }
        case .constellation: return result.sorted { $0.constellation.fullName < $1.constellation.fullName }
        case .spectralClass: return result.sorted { $0.spectralClass.rawValue < $1.spectralClass.rawValue }
        }
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
    @State private var sortOrder     = EStarSort.magnitude
    @State private var activeTab     = EListTab.solarSystem
    private let magnitudeRange = -2.0...8.0

    private var navTitle: String { isSearching ? "Search" : activeTab.rawValue }

    var body: some View {
        List {
            // Recents tab
            if showRecents {
                if recentDisplayed.isEmpty {
                    Section {
                        Text("No recently viewed stars yet.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    Section {
                        ForEach(recentDisplayed) { star in
                            NavigationLink(value: ESkyObject.star(star)) { EStarRowView(star: star) }
                        }
                    }
                }
            }

            // Solar System -- always visible when idle on that tab, or when searching
            if showSolarSystem && !solarSystemResults.isEmpty {
                Section {
                    ForEach(solarSystemResults) { obj in
                        NavigationLink(value: obj) { ESkyObjectRow(obj: obj) }
                    }
                }
            }

            // Constellations
            if showConstellations && !constellationResults.isEmpty {
                Section {
                    ForEach(constellationResults) { obj in
                        NavigationLink(value: obj) { ESkyObjectRow(obj: obj) }
                    }
                }
            }

            // Stars
            if showStars && !displayedStars.isEmpty {
                Section {
                    ForEach(displayedStars) { star in
                        NavigationLink(value: ESkyObject.star(star)) { EStarRowView(star: star) }
                    }
                }
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
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: Strings.Prompts.searchBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSortSheet = true } label: { Image(symbol: .magnitudeIcon) }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if activeTab == .stars {
                    Menu {
                        ForEach(EStarSort.allCases) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                Label(order.rawValue, systemImage: order.symbol)
                                if sortOrder == order { Image(systemName: "checkmark") }
                            }
                        }
                    } label: {
                        Image(symbol: .sort)
                    }
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
                .opacity(isSearching ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSearching)
            }
            
        }
        .sheet(isPresented: $showSortSheet) {
            EMagnitudeSlider(
                magnitudeCap: Bindable(state).magnitudeFilter,
                magnitudeRange: -2.0...8.0,
                starCount: displayedStars.count
            )
            .presentationDetents([.height(78)])
            .presentationDragIndicator(.visible)
        }
    }


}

#Preview {
    NavigationStack { EListView() }.environment(EAppState())
}

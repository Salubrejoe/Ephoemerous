import SwiftUI

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
        let all: [ESkyObject] = [.sun, .moon] + EPlanet.all
            .map { .planet($0) }
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
        var result = baseStars
            .filter { $0.magnitude <= state.magnitudeFilter }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { ESkyObject.star($0).searchTokens.contains(q) }
        }
        switch sortOrder {
        case .magnitude:
            result.sort { $0.magnitude < $1.magnitude }
        case .constellation:
            result.sort { $0.constellation.fullName < $1.constellation.fullName }
        case .name:
            result.sort { $0.name < $1.name }
        }
        return result
    }
    private var recentDisplayed: [EStar] {
        state.recentStars.filter { $0.magnitude <= state.magnitudeFilter }
    }
}

// MARK: - Components
extension EListView {

    
}



// MARK: - Main list

struct EListView: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss

    @State private var searchText    = ""
    @State private var sortOrder     = EStarSort.magnitude
    @State private var showSortSheet = false

    private let magnitudeRange = -2.0...8.0

    var body: some View {
        List {
            
            if searchText.isEmpty && !recentDisplayed.isEmpty {
                Section {
                    ForEach(recentDisplayed) { star in
                        NavigationLink(value: ESkyObject.star(star)) { EStarRowView(star: star) }
                    }
                } header: { header(title: .recentlyViewed) }
            }
            if searchText.isEmpty || solarSystemResults.count > 0 {
                Section {
                    ForEach(solarSystemResults) { obj in
                        NavigationLink(value: obj) { ESkyObjectRow(obj: obj) }
                    }
                } header: { header(title: .solarSystem) }
            }
            if searchText.isEmpty || constellationResults.count > 0 {
                Section {
                    ForEach(constellationResults) { obj in
                        NavigationLink(value: obj) { ESkyObjectRow(obj: obj) }
                    }
                } header: { header(title: .constellations) }
            }
            
            Section {
                ForEach(displayedStars) { star in
                    NavigationLink(value: ESkyObject.star(star)) { EStarRowView(star: star) }
                }
            } header: { if searchText.isEmpty { header(title: .allStars) } }
        }
        
        .navigationDestination(for: ESkyObject.self) { obj in
            switch obj {
            case .star(let s):
                EStarDetailView(star: s)
                    .onAppear { state.recordViewed(s) }
            case .sun:
                ENSSunDetailView()
            case .moon:
                ENSMoonDetailView()
            case .planet(let p):
                ENSPlanetDetailView(planet: p)
            case .constellation(let c):
                EConstellationDetailView(constellation: c)
            }
        }
        
        // SEARCH
        .searchable(text: $searchText, prompt: Strings.Prompts.searchBar)
        
        // SORT FILTER SHEET
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSortSheet = true } label: { Image(symbol: .sort) }
            }
        }
        .bottomSheet(
            .sortNFilter,
            isPresented: $showSortSheet,
            content: {
                ESortFilterSheet(
                    sortOrder: $sortOrder,
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

import SwiftUI

// MARK: - DetailHost
// Hosts the right detail view for the current `ESkyObject` destination.
// The NavigationStack is here so EConstellationDetailView can still
// push to EStarDetailView via NavigationLink, but the system nav bar
// is hidden — each detail view draws its own Apple-Maps-style
// `DetailHeader` (share / title / subtitle / icon / xmark) and
// `RememberButton` so the chrome looks the same regardless of how
// you got to it.
struct DetailHost: View {
    @Environment(EAppState.self) var state
    let obj: ESkyObject

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch obj {
        case .sun:                  ESunDetailView()
        case .moon:                 EMoonDetailView()
        case .star(let s):          EStarDetailView(star: s)
        case .planet(let p):        ENSPlanetDetailView(planet: p)
        case .constellation(let c): EConstellationDetailView(constellation: c)
        }
    }
}

import SwiftUI

// MARK: - DetailHost
// Hosts the right detail view for the current `ESkyObject` destination,
// with a top-trailing X-mark that dismisses via `state.dismissDetail()`.
//
// Behaviour-only for now. The detail-view internals (`EStarDetailView`,
// `ESunDetailView`, `EMoonDetailView`, `EConstellationDetailView`,
// `ENSPlanetDetailView`) are reused untouched — visual composition is a
// later pass. The NavigationStack is here so the existing
// `.navigationTitle` / `.toolbar` inside each detail still renders; the
// X-mark sits alongside as a `.topBarTrailing` toolbar item.
struct DetailHost: View {
    @Environment(EAppState.self) var state
    let obj: ESkyObject

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            state.dismissDetail()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.medium))
                        }
                        .accessibilityLabel("Dismiss")
                    }
                }
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

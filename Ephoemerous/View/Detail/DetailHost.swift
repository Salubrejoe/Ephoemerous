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

// MARK: - Detail collapsed flag
// True when the detail sheet is folded to its header-only detent
// (Apple-Maps place-card collapse). `DetailHeader` reads it to drop the
// POI icon, and each detail view reads it to drop its body — so the
// sheet shrinks to just title + subtitle + buttons, showing more canvas.
// Set on the sheet content in `MainView` from the selected detent.
private struct DetailCollapsedKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var detailCollapsed: Bool {
        get { self[DetailCollapsedKey.self] }
        set { self[DetailCollapsedKey.self] = newValue }
    }
}

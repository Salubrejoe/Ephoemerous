import SwiftUI

// MARK: - DetailHost
// Hosts the right detail view for the current `SkyObject` destination.
// The NavigationStack is here so ConstellationDetailView can still
// push to StarDetailView via NavigationLink, but the system nav bar
// is hidden — each detail view draws its own Apple-Maps-style
// `DetailHeader` (share / title / subtitle / icon / xmark) and
// `RememberButton` so the chrome looks the same regardless of how
// you got to it.
struct DetailHost: View {
    @Environment(AppState.self) var state
    let obj: SkyObject

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch obj {
        case .sun:                  SunDetailView()
        case .moon:                 MoonDetailView()
        case .star(let s):          StarDetailView(star: s)
        case .planet(let p):        PlanetDetailView(planet: p)
        case .constellation(let c): ConstellationDetailView(constellation: c)
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

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

    /// Whether to wrap the detail view in a `NavigationStack`.
    ///
    /// The sheet does (compact width): the constellation roster pushes to
    /// a star, with a chevron back to its parent. The iPad's floating
    /// panel does NOT — a NavigationStack always FILLS the height it is
    /// given and can never report a natural one, so the card could only
    /// ever be a fixed slab. Without it the panel hugs its content, and
    /// the roster SELECTS the star instead of pushing to it: the panel's
    /// contents swap, which is the Maps idiom on a big screen anyway.
    var stacked: Bool = true

    var body: some View {
        if stacked {
            NavigationStack {
                content
                    .toolbar(.hidden, for: .navigationBar)
            }
        } else {
            content
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

    /// True when the detail view is hosted by the iPad's `FloatingPanel`
    /// rather than a sheet — i.e. there is no `NavigationStack` to push
    /// onto. Read by `ConstellationDetailView`'s roster, which selects
    /// instead of pushing.
    var detailInPanel: Bool {
        get { self[DetailInPanelKey.self] }
        set { self[DetailInPanelKey.self] = newValue }
    }
}

private struct DetailInPanelKey: EnvironmentKey {
    static let defaultValue = false
}

#if DEBUG
#Preview("Detail host") {
    DetailHost(obj: .star(PreviewSky.someStar))
        .environment(AppState())
}
#endif

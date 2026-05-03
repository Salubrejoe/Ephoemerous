import Foundation

// MARK: - ECloudSync
@MainActor
final class ECloudSync {

    static let shared = ECloudSync()
    private let store = NSUbiquitousKeyValueStore.default
    private let db    = StarDatabase.shared

    private enum Key {
        static let selectedStars    = "selectedStarNames"
        static let recentStars      = "recentStarNames"
        static let showEquator      = "layerShowEquator"
        static let showEcliptic     = "layerShowEcliptic"
        static let showNSMeridians  = "layerShowNSMeridians"
        static let showULMeridians  = "layerShowULMeridians"
        static let showHorizon      = "layerShowHorizon"
        static let showStars        = "layerShowStars"
        static let showPlanets      = "layerShowPlanets"
        static let showSelectedStars = "layerShowSelectedStars"
    }

    // MARK: - Bootstrap
    func start(appState: EAppState) {
        appState.selectedStars       = resolve(key: Key.selectedStars)
        appState.setRecentStars(resolve(key: Key.recentStars))
        loadLayerVisibility(into: appState)

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self, weak appState] _ in
            MainActor.assumeIsolated {
                guard let self, let appState else { return }
                appState.selectedStars = self.resolve(key: Key.selectedStars)
                appState.setRecentStars(self.resolve(key: Key.recentStars))
                self.loadLayerVisibility(into: appState)
                ELogger.selectedStars("iCloud pushed updates")
            }
        }

        store.synchronize()
    }

    // MARK: - Write
    func saveSelectedStars(_ stars: [EStar]) {
        store.set(stars.map(\.name), forKey: Key.selectedStars)
        store.synchronize()
    }

    func saveRecentStars(_ stars: [EStar]) {
        store.set(stars.map(\.name), forKey: Key.recentStars)
        store.synchronize()
    }

    // MARK: - Read
    private func resolve(key: String) -> [EStar] {
        guard let names = store.array(forKey: key) as? [String] else { return [] }
        let all = db.workableStars
        var seen = Set<String>()
        return names.compactMap { name -> EStar? in
            guard !seen.contains(name), let star = all.first(where: { $0.name == name })
            else { return nil }
            seen.insert(name)
            return star
        }
    }

    // MARK: - Layer visibility
    // TODO: Persist - layer visibility is saved but projectionMode and appMode are not; consider persisting them too
    func saveLayerVisibility(_ state: EAppState) {
        store.set(state.showEquatorTropics,   forKey: Key.showEquator)
        store.set(state.showEcliptic,         forKey: Key.showEcliptic)
        store.set(state.showNSMeridians,      forKey: Key.showNSMeridians)
        store.set(state.showULMeridians,      forKey: Key.showULMeridians)
        store.set(state.showHorizon,          forKey: Key.showHorizon)
        store.set(state.showStars,            forKey: Key.showStars)
        store.set(state.showPlanets,          forKey: Key.showPlanets)
        store.set(state.showSelectedStars,    forKey: Key.showSelectedStars)
        store.synchronize()
    }

    func loadLayerVisibility(into state: EAppState) {
        if store.object(forKey: Key.showEquator)       != nil { state.showEquatorTropics  = store.bool(forKey: Key.showEquator) }
        if store.object(forKey: Key.showEcliptic)      != nil { state.showEcliptic        = store.bool(forKey: Key.showEcliptic) }
        if store.object(forKey: Key.showNSMeridians)   != nil { state.showNSMeridians     = store.bool(forKey: Key.showNSMeridians) }
        if store.object(forKey: Key.showULMeridians)   != nil { state.showULMeridians     = store.bool(forKey: Key.showULMeridians) }
        if store.object(forKey: Key.showHorizon)       != nil { state.showHorizon         = store.bool(forKey: Key.showHorizon) }
        if store.object(forKey: Key.showStars)         != nil { state.showStars           = store.bool(forKey: Key.showStars) }
        if store.object(forKey: Key.showPlanets)       != nil { state.showPlanets         = store.bool(forKey: Key.showPlanets) }
        if store.object(forKey: Key.showSelectedStars) != nil { state.showSelectedStars   = store.bool(forKey: Key.showSelectedStars) }
    }
}

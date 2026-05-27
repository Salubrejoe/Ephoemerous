import Foundation

// MARK: - ECloudSync
// iCloud key-value persistence for the three pieces of state worth
// syncing across devices: the user's selected + recent stars, and
// the magnitude filter slider. Per-layer visibility toggles used to
// live here too; they're gone — every layer is always visible now,
// so only the magnitude slider remains as a user-facing display knob.
@MainActor
final class ECloudSync {

    static let shared = ECloudSync()
    private let store = NSUbiquitousKeyValueStore.default
    private let db    = StarDatabase.shared

    private enum Key {
        static let selectedStars    = "selectedStarNames"
        static let recentStars      = "recentStarNames"
        static let magnitudeFilter  = "magnitudeFilter"
    }

    // MARK: - Bootstrap
    func start(appState: EAppState) {
        appState.selectedStars = resolve(key: Key.selectedStars)
        appState.setRecentStars(resolve(key: Key.recentStars))
        loadMagnitudeFilter(into: appState)

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self, weak appState] _ in
            MainActor.assumeIsolated {
                guard let self, let appState else { return }
                appState.selectedStars = self.resolve(key: Key.selectedStars)
                appState.setRecentStars(self.resolve(key: Key.recentStars))
                self.loadMagnitudeFilter(into: appState)
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

    func saveMagnitudeFilter(_ value: Double) {
        store.set(value, forKey: Key.magnitudeFilter)
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

    private func loadMagnitudeFilter(into state: EAppState) {
        if store.object(forKey: Key.magnitudeFilter) != nil {
            state.magnitudeFilter = store.double(forKey: Key.magnitudeFilter)
        }
    }
}

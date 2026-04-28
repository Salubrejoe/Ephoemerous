import Foundation

// MARK: - ECloudSync
@MainActor
final class ECloudSync {

    static let shared = ECloudSync()
    private let store = NSUbiquitousKeyValueStore.default
    private let db    = StarDatabase.shared

    private enum Key {
        static let selectedStars = "selectedStarNames"
        static let recentStars   = "recentStarNames"
    }

    // MARK: - Bootstrap
    func start(appState: EAppState) {
        appState.selectedStars   = resolve(key: Key.selectedStars)
        appState.setRecentStars(resolve(key: Key.recentStars))

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self, weak appState] _ in
            MainActor.assumeIsolated {
                guard let self, let appState else { return }
                appState.selectedStars = self.resolve(key: Key.selectedStars)
                appState.setRecentStars(self.resolve(key: Key.recentStars))
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
        return names.compactMap { name in all.first { $0.name == name } }
    }
}
import Foundation

// MARK: - ECloudSync
// iCloud key-value persistence for the three pieces of state worth
// syncing across devices: the user's favourites + recent stars, and
// the magnitude filter slider. Per-layer visibility toggles used to
// live here too; they're gone — every layer is always visible now,
// so only the magnitude slider remains as a user-facing display knob.
//
// Favourites are stored generically as `[ESkyObject]` in app state, but
// for now only the `.star` cases are persisted — the existing iCloud
// key `selectedStarNames` (carrying Bayer designations) is preserved
// for backward compatibility with already-synced devices. When sun /
// moon / planet / constellation favourites get their own UI, extend
// the encoder/decoder to handle their `ESkyObject.id` strings.
@MainActor
final class ECloudSync {

    static let shared = ECloudSync()
    private let store = NSUbiquitousKeyValueStore.default
    private let db    = StarDatabase.shared

    private enum Key {
        static let favouriteStars   = "selectedStarNames"   // legacy key, keep
        static let recentStars      = "recentStarNames"
        static let magnitudeFilter  = "magnitudeFilter"
    }

    // MARK: - Bootstrap
    func start(appState: EAppState) {
        appState.favourites = resolveFavourites()
        appState.setRecentStars(resolveStars(key: Key.recentStars))
        loadMagnitudeFilter(into: appState)

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self, weak appState] _ in
            MainActor.assumeIsolated {
                guard let self, let appState else { return }
                appState.favourites = self.resolveFavourites()
                appState.setRecentStars(self.resolveStars(key: Key.recentStars))
                self.loadMagnitudeFilter(into: appState)
                ELogger.favourites("iCloud pushed updates")
            }
        }

        store.synchronize()
    }

    // MARK: - Write

    /// Persist the favourites list. For now only the `.star` cases are
    /// encoded (under the legacy iCloud key) — non-star favourites
    /// round-trip as a no-op until we extend the schema.
    func saveFavourites(_ favs: [ESkyObject]) {
        let starNames: [String] = favs.compactMap { obj in
            if case .star(let s) = obj { return s.name } else { return nil }
        }
        store.set(starNames, forKey: Key.favouriteStars)
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

    /// Read favourites from iCloud. Currently the only encoded subset
    /// is stars (legacy key, Bayer-designation strings) — wrap each in
    /// `ESkyObject.star(...)` on the way back out.
    private func resolveFavourites() -> [ESkyObject] {
        resolveStars(key: Key.favouriteStars).map { ESkyObject.star($0) }
    }

    private func resolveStars(key: String) -> [EStar] {
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

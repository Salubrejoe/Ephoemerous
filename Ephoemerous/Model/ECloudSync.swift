import Foundation

// MARK: - ECloudSync
// iCloud key-value persistence for the three pieces of state worth
// syncing across devices: the user's favourites + recent stars, and
// the magnitude filter slider. Per-layer visibility toggles used to
// live here too; they're gone — every layer is always visible now,
// so only the magnitude slider remains as a user-facing display knob.
//
// Favourites round-trip as `[ESkyObject]`. Each case has its own
// iCloud key + decoder so a future schema bump (e.g. adding a new
// ESkyObject case) only touches one switch arm. The legacy
// `selectedStarNames` key is preserved for backward compatibility
// with already-synced devices — it's still the canonical key for
// star favourites.
@MainActor
final class ECloudSync {

    static let shared = ECloudSync()
    private let store = NSUbiquitousKeyValueStore.default
    private let db    = StarDatabase.shared

    private enum Key {
        static let favouriteStars          = "selectedStarNames"            // legacy key, keep
        static let favouriteConstellations = "favouriteConstellationRaws"
        static let favouritePlanets        = "favouritePlanetNames"
        static let favouriteSun            = "favouriteSun"
        static let favouriteMoon           = "favouriteMoon"
        static let recentStars             = "recentStarNames"
        static let magnitudeFilter         = "magnitudeFilter"
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

    /// Persist the favourites list. Every `ESkyObject` case has its
    /// own iCloud key — list-shaped for stars / constellations /
    /// planets, boolean for the singletons (sun, moon). The didSet on
    /// `EAppState.favourites` calls this on every change.
    func saveFavourites(_ favs: [ESkyObject]) {
        var starNames:   [String] = []
        var consRaws:    [String] = []
        var planetNames: [String] = []
        var sunFav       = false
        var moonFav      = false
        for fav in favs {
            switch fav {
            case .star(let s):          starNames.append(s.name)
            case .constellation(let c): consRaws.append(c.rawValue)
            case .planet(let p):        planetNames.append(p.name)
            case .sun:                  sunFav  = true
            case .moon:                 moonFav = true
            }
        }
        store.set(starNames,   forKey: Key.favouriteStars)
        store.set(consRaws,    forKey: Key.favouriteConstellations)
        store.set(planetNames, forKey: Key.favouritePlanets)
        store.set(sunFav,      forKey: Key.favouriteSun)
        store.set(moonFav,     forKey: Key.favouriteMoon)
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

    /// Read favourites from every case-specific iCloud key and wrap
    /// each back into its `ESkyObject` form. Cross-type ordering is
    /// not preserved (stars come back first, then constellations,
    /// then planets, then sun/moon) — within each type, insertion
    /// order is preserved by the underlying array storage.
    private func resolveFavourites() -> [ESkyObject] {
        var result: [ESkyObject] = []
        result.append(contentsOf: resolveStars(key: Key.favouriteStars).map(ESkyObject.star))
        result.append(contentsOf: resolveConstellations().map(ESkyObject.constellation))
        result.append(contentsOf: resolvePlanets().map(ESkyObject.planet))
        if store.bool(forKey: Key.favouriteSun)  { result.append(.sun)  }
        if store.bool(forKey: Key.favouriteMoon) { result.append(.moon) }
        return result
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

    private func resolveConstellations() -> [EConstellation] {
        guard let raws = store.array(forKey: Key.favouriteConstellations) as? [String] else { return [] }
        var seen = Set<String>()
        return raws.compactMap { raw -> EConstellation? in
            guard !seen.contains(raw), let cons = EConstellation(rawValue: raw) else { return nil }
            seen.insert(raw)
            return cons
        }
    }

    private func resolvePlanets() -> [EPlanet] {
        guard let names = store.array(forKey: Key.favouritePlanets) as? [String] else { return [] }
        var seen = Set<String>()
        return names.compactMap { name -> EPlanet? in
            guard !seen.contains(name),
                  let planet = EPlanet.all.first(where: { $0.name == name })
            else { return nil }
            seen.insert(name)
            return planet
        }
    }

    private func loadMagnitudeFilter(into state: EAppState) {
        if store.object(forKey: Key.magnitudeFilter) != nil {
            state.magnitudeFilter = store.double(forKey: Key.magnitudeFilter)
        }
    }
}

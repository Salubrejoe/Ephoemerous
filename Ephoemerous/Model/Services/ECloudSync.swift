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
        static let recentObjects           = "recentObjectIDs"   // universal recents (ESkyObject.id)
        static let magnitudeFilter         = "magnitudeFilter"
    }

    // MARK: - Bootstrap
    func start(appState: EAppState) {
        appState.favourites = resolveFavourites()
        appState.setRecentStars(resolveStars(key: Key.recentStars))
        appState.setRecentObjects(resolveRecentObjects())
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
                appState.setRecentObjects(self.resolveRecentObjects())
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

    /// Persist the universal recents list by `ESkyObject.id`
    /// ("sun" / "planet_mars" / "constellation_orion" / "star_<uuid>").
    /// Note: a star's id is a per-launch UUID, so star recents don't
    /// survive relaunch through this key — `resolveRecentObjects` falls
    /// back to the name-keyed `recentStars` list for those. Mixed-type
    /// order is preserved here; star ordering is best-effort on restore.
    func saveRecentObjects(_ objects: [ESkyObject]) {
        store.set(objects.map(\.id), forKey: Key.recentObjects)
        store.synchronize()
    }

    func saveMagnitudeFilter(_ value: Double) {
        store.set(value, forKey: Key.magnitudeFilter)
        store.synchronize()
    }

    // MARK: - Read

    /// Favourites straight from the store — for callers that live outside
    /// the `EAppState` observation graph (App Intents entity queries, and
    /// later the widget process, where no app state exists at all).
    func favourites() -> [ESkyObject] { resolveFavourites() }

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

    /// Rebuild the universal recents list from stored `ESkyObject.id`s.
    /// sun / moon / planet / constellation resolve directly from their
    /// id. Stars can't (their id is a per-launch UUID), so star slots
    /// are back-filled from the name-keyed `recentStars` list in stored
    /// order — best-effort, but it keeps stars in Recents across launches.
    private func resolveRecentObjects() -> [ESkyObject] {
        guard let ids = store.array(forKey: Key.recentObjects) as? [String] else {
            // No universal list yet (first run after the upgrade) — seed
            // from the legacy stars-only recents so it isn't empty.
            return resolveStars(key: Key.recentStars).map(ESkyObject.star)
        }
        let recentStarsByOrder = resolveStars(key: Key.recentStars)
        var starCursor = 0
        var seen = Set<String>()
        var out: [ESkyObject] = []
        for id in ids {
            let obj: ESkyObject?
            if id == "sun" {
                obj = .sun
            } else if id == ESkyObject.moon.id {
                obj = .moon
            } else if id.hasPrefix("planet_") {
                let name = String(id.dropFirst("planet_".count))
                obj = EPlanet.all.first { $0.id == name }.map(ESkyObject.planet)
            } else if id.hasPrefix("constellation_") {
                let raw = String(id.dropFirst("constellation_".count))
                obj = EConstellation(rawValue: raw).map(ESkyObject.constellation)
            } else if id.hasPrefix("star_") {
                // UUID won't match a fresh star; pull the next name-keyed
                // recent star in order as the stand-in.
                obj = starCursor < recentStarsByOrder.count
                    ? .star(recentStarsByOrder[starCursor]) : nil
                if obj != nil { starCursor += 1 }
            } else {
                obj = nil
            }
            if let obj, seen.insert(obj.id).inserted { out.append(obj) }
        }
        return out
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

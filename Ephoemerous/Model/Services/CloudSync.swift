import Foundation

// MARK: - CloudSync
// iCloud key-value persistence for the three pieces of state worth
// syncing across devices: the user's favourites + recent stars, and
// the magnitude filter slider. Per-layer visibility toggles used to
// live here too; they're gone — every layer is always visible now,
// so only the magnitude slider remains as a user-facing display knob.
//
// Favourites round-trip as `[SkyObject]`. Each case has its own
// iCloud key + decoder so a future schema bump (e.g. adding a new
// SkyObject case) only touches one switch arm. The legacy
// `selectedStarNames` key is preserved for backward compatibility
// with already-synced devices — it's still the canonical key for
// star favourites.
@MainActor
final class CloudSync {

    static let shared = CloudSync()
    private let store = NSUbiquitousKeyValueStore.default
    /// Read side — shared with the widget process (see `FavouritesStore`).
    private let reads = FavouritesStore()

    private enum Key {
        static let favouriteStars          = FavouritesStore.Key.favouriteStars
        static let favouriteConstellations = FavouritesStore.Key.favouriteConstellations
        static let favouritePlanets        = FavouritesStore.Key.favouritePlanets
        static let favouriteSun            = FavouritesStore.Key.favouriteSun
        static let favouriteMoon           = FavouritesStore.Key.favouriteMoon
        static let recentStars             = "recentStarNames"
        static let recentObjects           = "recentObjectIDs"   // universal recents (SkyObject.id)
        static let magnitudeFilter         = "magnitudeFilter"
    }

    // MARK: - Bootstrap
    func start(appState: AppState) {
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
                Logger.favourites("iCloud pushed updates")
            }
        }

        store.synchronize()
    }

    // MARK: - Write

    /// Persist the favourites list. Every `SkyObject` case has its
    /// own iCloud key — list-shaped for stars / constellations /
    /// planets, boolean for the singletons (sun, moon). The didSet on
    /// `AppState.favourites` calls this on every change.
    func saveFavourites(_ favs: [SkyObject]) {
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

    func saveRecentStars(_ stars: [Star]) {
        store.set(stars.map(\.name), forKey: Key.recentStars)
        store.synchronize()
    }

    /// Persist the universal recents list by `SkyObject.id`
    /// ("sun" / "planet_mars" / "constellation_orion" / "star_<uuid>").
    /// Note: a star's id is a per-launch UUID, so star recents don't
    /// survive relaunch through this key — `resolveRecentObjects` falls
    /// back to the name-keyed `recentStars` list for those. Mixed-type
    /// order is preserved here; star ordering is best-effort on restore.
    func saveRecentObjects(_ objects: [SkyObject]) {
        store.set(objects.map(\.id), forKey: Key.recentObjects)
        store.synchronize()
    }

    func saveMagnitudeFilter(_ value: Double) {
        store.set(value, forKey: Key.magnitudeFilter)
        store.synchronize()
    }

    /// Park the observer origin for the widget process (see
    /// `FavouritesStore.observerOrigin`). Called on scene-background —
    /// NOT on every origin tween; KVS writes are quota'd.
    func saveObserverOrigin(latDeg: Double, lonDeg: Double) {
        store.set(latDeg, forKey: FavouritesStore.Key.observerLatDeg)
        store.set(lonDeg, forKey: FavouritesStore.Key.observerLonDeg)
        store.synchronize()
    }

    // MARK: - Read

    /// Favourites straight from the store — for callers that live outside
    /// the `AppState` observation graph (App Intents entity queries, and
    /// the widget process, where no app state exists at all). Delegates
    /// to the shared `FavouritesStore` read side.
    func favourites() -> [SkyObject] { reads.favourites() }

    private func resolveFavourites() -> [SkyObject] { reads.favourites() }

    /// Rebuild the universal recents list from stored `SkyObject.id`s.
    /// sun / moon / planet / constellation resolve directly from their
    /// id. Stars can't (their id is a per-launch UUID), so star slots
    /// are back-filled from the name-keyed `recentStars` list in stored
    /// order — best-effort, but it keeps stars in Recents across launches.
    private func resolveRecentObjects() -> [SkyObject] {
        guard let ids = store.array(forKey: Key.recentObjects) as? [String] else {
            // No universal list yet (first run after the upgrade) — seed
            // from the legacy stars-only recents so it isn't empty.
            return resolveStars(key: Key.recentStars).map(SkyObject.star)
        }
        let recentStarsByOrder = resolveStars(key: Key.recentStars)
        var starCursor = 0
        var seen = Set<String>()
        var out: [SkyObject] = []
        for id in ids {
            let obj: SkyObject?
            if id == "sun" {
                obj = .sun
            } else if id == SkyObject.moon.id {
                obj = .moon
            } else if id.hasPrefix("planet_") {
                let name = String(id.dropFirst("planet_".count))
                obj = Planet.all.first { $0.id == name }.map(SkyObject.planet)
            } else if id.hasPrefix("constellation_") {
                let raw = String(id.dropFirst("constellation_".count))
                obj = Constellation(rawValue: raw).map(SkyObject.constellation)
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

    private func resolveStars(key: String) -> [Star] {
        reads.stars(key: key)
    }

    private func loadMagnitudeFilter(into state: AppState) {
        if store.object(forKey: Key.magnitudeFilter) != nil {
            state.magnitudeFilter = store.double(forKey: Key.magnitudeFilter)
        }
    }
}

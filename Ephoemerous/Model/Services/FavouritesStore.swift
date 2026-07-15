import Foundation

// MARK: - FavouritesStore
// The READ side of favourites persistence, split out of `ECloudSync` so
// it compiles in processes that have no `EAppState` at all — the widget
// extension resolves the user's remembered objects through this exact
// type, against the exact keys the app writes. `ECloudSync` (app-only)
// keeps ownership of writes + the iCloud-change subscription and
// delegates its reads here.
//
// Favourites round-trip as `[ESkyObject]`. Each case has its own iCloud
// key + decoder so a schema bump only touches one switch arm. The legacy
// `selectedStarNames` key stays the canonical key for star favourites.
@MainActor
struct FavouritesStore {

    enum Key {
        static let favouriteStars          = "selectedStarNames"            // legacy key, keep
        static let favouriteConstellations = "favouriteConstellationRaws"
        static let favouritePlanets        = "favouritePlanetNames"
        static let favouriteSun            = "favouriteSun"
        static let favouriteMoon           = "favouriteMoon"
        static let observerLatDeg          = "observerLatDeg"
        static let observerLonDeg          = "observerLonDeg"
    }

    private let store = NSUbiquitousKeyValueStore.default

    /// Read favourites from every case-specific iCloud key and wrap
    /// each back into its `ESkyObject` form. Cross-type ordering is
    /// not preserved (stars come back first, then constellations,
    /// then planets, then sun/moon) — within each type, insertion
    /// order is preserved by the underlying array storage.
    func favourites() -> [ESkyObject] {
        var result: [ESkyObject] = []
        result.append(contentsOf: stars(key: Key.favouriteStars).map(ESkyObject.star))
        result.append(contentsOf: constellations().map(ESkyObject.constellation))
        result.append(contentsOf: planets().map(ESkyObject.planet))
        if store.bool(forKey: Key.favouriteSun)  { result.append(.sun)  }
        if store.bool(forKey: Key.favouriteMoon) { result.append(.moon) }
        return result
    }

    /// Stars stored under `key` (favourites or recents — the caller
    /// picks), resolved by canonical name against the database.
    func stars(key: String) -> [EStar] {
        guard let names = store.array(forKey: key) as? [String] else { return [] }
        let all = StarDatabase.shared.workableStars
        var seen = Set<String>()
        return names.compactMap { name -> EStar? in
            guard !seen.contains(name), let star = all.first(where: { $0.name == name })
            else { return nil }
            seen.insert(name)
            return star
        }
    }

    func constellations() -> [EConstellation] {
        guard let raws = store.array(forKey: Key.favouriteConstellations) as? [String] else { return [] }
        var seen = Set<String>()
        return raws.compactMap { raw -> EConstellation? in
            guard !seen.contains(raw), let cons = EConstellation(rawValue: raw) else { return nil }
            seen.insert(raw)
            return cons
        }
    }

    /// The observer origin the app last parked at (degrees), written by
    /// `ECloudSync.saveObserverOrigin` when the app backgrounds. This is
    /// how the widget knows WHERE the sky is being watched from — a
    /// widget process has no location access. `nil` before the app has
    /// ever backgrounded.
    func observerOrigin() -> (latDeg: Double, lonDeg: Double)? {
        guard store.object(forKey: Key.observerLatDeg) != nil else { return nil }
        return (store.double(forKey: Key.observerLatDeg),
                store.double(forKey: Key.observerLonDeg))
    }

    func planets() -> [EPlanet] {
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
}

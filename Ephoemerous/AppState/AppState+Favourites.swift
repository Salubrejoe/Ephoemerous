import Foundation

// MARK: - AppState + Favourites
// Universal favourites system. Replaces the old `selectedStars: [Star]`
// special case with `favourites: [SkyObject]` so any sky object can be
// favourited — stars today, planets / constellations / sun / moon as
// their UX gets wired up.
//
// Visual rendering for favourites lives in `FavouritesLayer`; persistence
// lives in `CloudSync`. The helpers here are the small predicate /
// toggle / fast-lookup surface that callers across the codebase need.
extension AppState {

    /// Is `obj` currently in the favourites list?
    func isFavourite(_ obj: SkyObject) -> Bool {
        favourites.contains { $0.id == obj.id }
    }

    /// Add `obj` if absent, remove if present. Triggers the didSet
    /// on `favourites` which logs + persists.
    func toggleFavourite(_ obj: SkyObject) {
        if let idx = favourites.firstIndex(where: { $0.id == obj.id }) {
            favourites.remove(at: idx)
        } else {
            favourites.append(obj)
        }
    }

    /// Shortcut for the most common predicate in hot draw loops —
    /// "is this Star in the favourites?". Same cost as the old
    /// `selectedStars.contains(star)` (linear scan); precompute a
    /// `Set<String>` per frame if it shows up in profiling.
    func isFavouriteStar(_ star: Star) -> Bool {
        favourites.contains { obj in
            if case .star(let s) = obj { return s.name == star.name }
            return false
        }
    }

    /// Just the star favourites, in order. Used by `NamedStarsLayer`
    /// for its skip-if-favourite check and by anyone else needing
    /// the Star list directly (cloud sync, recents migration, …).
    var favouriteStars: [Star] {
        favourites.compactMap { obj in
            if case .star(let s) = obj { return s } else { return nil }
        }
    }

    /// Just the constellation favourites. Used by
    /// `ConstellationNamesLayer` for its skip-if-favourite check
    /// (so the badge isn't drawn twice — `FavouritesLayer` takes
    /// over the draw with a heart overlay).
    var favouriteConstellations: [Constellation] {
        favourites.compactMap { obj in
            if case .constellation(let c) = obj { return c } else { return nil }
        }
    }
}

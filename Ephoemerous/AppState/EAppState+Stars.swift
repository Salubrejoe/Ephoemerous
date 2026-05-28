import SwiftUI
import simd
import LoreKit

// MARK: - EAppState + Stars
// Star filtering, magnitude caching, selection history, and recently viewed.
// The cache is keyed on (observationDate, origin, magnitudeFilter) — any change
// to those values calls invalidateStarCache(), which is wired up via didSet in EAppState.swift.
extension EAppState {

    // MARK: Cache management

    /// Drop the star cache. Called automatically when observationDate,
    /// magnitudeFilter, or origin changes.
    func invalidateStarCache() {
        _starsCache = nil
    }

    // MARK: Filtered star collections

    /// All workable stars filtered by magnitude. Cached until the
    /// cache is invalidated (origin / date / magnitude change) so the
    /// filter runs once per rebuild, never per frame. (Previously
    /// there were two getters — `stars` with horizon culling for
    /// clock mode and `travelStars` for travel mode — but the horizon
    /// filter had been commented out, leaving the two identical, and
    /// appMode itself is gone now.)
    var stars: [EStar] {
        if let cached = _starsCache { return cached }
        let result = StarDatabase.shared.workableStars
            .filter { $0.name != "Unknown" && $0.magnitude < magnitudeFilter }
        _starsCache = result
        return result
    }

    // MARK: Recently viewed

    /// Seed the recents list (e.g. from CloudKit on launch).
    func setRecentStars(_ stars: [EStar]) {
        recentStars = stars
    }

    /// Push a star to the front of the recents list, capping at 10 entries.
    /// Persists the updated list to CloudKit.
    func recordViewed(_ star: EStar) {
        var updated = recentStars.filter { $0.id != star.id }
        updated.insert(star, at: 0)
        if updated.count > 10 { updated = Array(updated.prefix(10)) }
        recentStars = updated
        ECloudSync.shared.saveRecentStars(updated)
    }
}

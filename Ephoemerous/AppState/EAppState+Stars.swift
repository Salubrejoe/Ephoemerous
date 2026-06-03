import SwiftUI
import simd
import LoreKit

// MARK: - EAppState + Stars
// Star set (magnitude-sorted cache + zoom-driven visible prefix),
// selection history, and recently viewed. The sorted cache depends only
// on (observationDate, origin); magnitude is no longer a cache key — the
// visible cap is applied per frame from zoom (see `visibleStars`).
extension EAppState {

    // MARK: Cache management

    /// Drop the magnitude-sorted star cache. Called automatically when
    /// observationDate or origin changes (wired via didSet in
    /// EAppState.swift / setOrigin).
    func invalidateStarCache() {
        _starsCache = nil
    }

    // MARK: Zoom-driven magnitude cap

    /// Visible magnitude limit as a function of zoom. Zooming in reveals
    /// fainter stars (telescope-style); zooming out keeps only the
    /// brighter ones so the wide view breathes. Anchored to the gesture
    /// scale range (floor 25 → default 215 → ceiling 500):
    ///
    ///   • scale ≤ 25  → mag ≤ 4.5  (bright stars only; clean wide sky)
    ///   • scale 215   → mag ≤ 6.2  (≈ naked-eye, the resting look)
    ///   • scale ≥ 500 → mag ≤ 8.0  (catalog-deep, the BSC's practical floor)
    ///
    /// Two linear segments through those anchors, clamped at the ends.
    /// Smooth enough that stars fade in as you pinch rather than popping.
    func magnitudeCap(forScale scale: Double) -> Double {
        let floorScale   = 25.0,  floorMag   = 4.5
        let defaultScale = 215.0, defaultMag = 6.2
        let ceilScale    = 500.0, ceilMag    = 8.0

        if scale <= floorScale { return floorMag }
        if scale >= ceilScale  { return ceilMag }
        if scale <= defaultScale {
            let t = (scale - floorScale) / (defaultScale - floorScale)
            return floorMag + (defaultMag - floorMag) * t
        }
        let t = (scale - defaultScale) / (ceilScale - defaultScale)
        return defaultMag + (ceilMag - defaultMag) * t
    }

    // MARK: Filtered star collections

    /// All workable stars, sorted brightest-first (ascending magnitude),
    /// cached. Sorting once lets the per-frame visible set be a cheap
    /// PREFIX (take stars while magnitude < the zoom cap) instead of a
    /// full re-filter of ~9k every frame. Invalidated on origin / date
    /// change (the same triggers as before; magnitude is no longer a
    /// cache key — it's applied per frame from zoom via `visibleStars`).
    var sortedStars: [EStar] {
        if let cached = _starsCache { return cached }
        let result = StarDatabase.shared.workableStars
            .sorted { $0.magnitude < $1.magnitude }
        _starsCache = result
        return result
    }

    /// Stars to draw at the current zoom: the magnitude-sorted set
    /// truncated at the zoom-driven cap. Because `sortedStars` is sorted
    /// ascending, this is a contiguous brightest-first prefix — found
    /// with a single scan to the first star past the cap, no allocation
    /// of a filtered copy.
    func visibleStars(forScale scale: Double) -> ArraySlice<EStar> {
        let cap = magnitudeCap(forScale: scale)
        let all = sortedStars
        // First index whose magnitude is at/above the cap → prefix end.
        let end = all.firstIndex { $0.magnitude >= cap } ?? all.count
        return all[..<end]
    }

    /// Back-compat shim — callers that want "the current star set"
    /// without threading scale. Uses the rendered scale's cap.
    var stars: [EStar] {
        Array(visibleStars(forScale: renderedScale))
    }

    // MARK: Recently viewed

    /// Seed the recents list (e.g. from CloudKit on launch).
    func setRecentStars(_ stars: [EStar]) {
        recentStars = stars
    }

    /// Push a star to the front of the (legacy stars-only) recents list,
    /// capping at 10 entries. Persists to CloudKit.
    func recordViewed(_ star: EStar) {
        var updated = recentStars.filter { $0.id != star.id }
        updated.insert(star, at: 0)
        if updated.count > 10 { updated = Array(updated.prefix(10)) }
        recentStars = updated
        ECloudSync.shared.saveRecentStars(updated)
    }

    /// Seed the universal recents list (e.g. from CloudKit on launch).
    func setRecentObjects(_ objects: [ESkyObject]) {
        recentObjects = objects
    }

    /// Push any sky object to the front of the universal recents list,
    /// deduped by id and capped at 10. Called from `focus(on:)` so every
    /// opened object — star, sun, moon, planet, constellation — lands
    /// here. Persists by id via ECloudSync.
    func recordViewed(_ object: ESkyObject) {
        var updated = recentObjects.filter { $0.id != object.id }
        updated.insert(object, at: 0)
        if updated.count > 10 { updated = Array(updated.prefix(10)) }
        recentObjects = updated
        ECloudSync.shared.saveRecentObjects(updated)
    }
}

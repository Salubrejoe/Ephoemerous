import SwiftUI
import simd
import LoreKit

// MARK: - Star projection cache key
// The PROJECTION invariants — the only inputs to precess → project (a
// star's projection-unit point). `canvasRotation`, `scale` and `offset`
// are applied afterwards in `EGraphicContext.toScreen`, so they're NOT
// keys: pan, pinch and rotate all share one key and reuse the cached
// projections, re-running only the cheap toScreen. The cache is rebuilt
// only when date or origin changes. See `StarsLayer`.
struct StarProjectionKey: Equatable {
    let date: Date
    let lat:  Double
    let lon:  Double
}

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
    /// scale range — floor → default → ceiling pulled from
    /// AstroConstants so the curve can't drift from the real zoom limits:
    ///
    ///   • zoom-out floor   → mag ≤ 4.5  (bright stars only; clean sky)
    ///   • default (215)    → mag ≤ 6.2  (≈ naked-eye, the resting look)
    ///   • zoom-in ceiling  → mag ≤ 8.0  (catalog-deep, the BSC's floor)
    ///
    /// Two linear segments through those anchors, clamped at the ends.
    /// Smooth enough that stars fade in as you pinch rather than popping.
    func magnitudeCap(forScale scale: Double) -> Double {
        let floorScale   = 25.0,                       floorMag   = 4.5
        let defaultScale = AstroConstants.defaultScale, defaultMag = 6.2
        let ceilScale    = AstroConstants.maximumScale, ceilMag    = 8.0

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

    /// Scale to compute the magnitude cap at. During a camera transition
    /// this is the DESTINATION scale, not the live interpolating one —
    /// so the visible star *count* is fixed at its final value for the
    /// whole pan instead of growing frame-by-frame as the zoom ramps.
    ///
    /// That per-frame growth was the star-pan stutter: a star-tap zooms
    /// to a deep scale (namedStar textIn 360 ≈ scale 432), and the rising
    /// magnitude cap kept ADDING stars to the draw every frame of the
    /// pan. Freezing the cap at the target means the final-density field
    /// is present from frame 1 and simply slides into place. (Sun/planets
    /// pan to a shallow scale where the cap barely moves — hence they
    /// were already smooth.) Position still animates via `renderedScale`;
    /// only the membership cap is frozen.
    var magnitudeScale: Double {
        _activeTransition?.toScale ?? renderedScale
    }

    /// Stars to draw: the magnitude-sorted set truncated at the cap for
    /// `magnitudeScale`. Because `sortedStars` is sorted ascending, this
    /// is a contiguous brightest-first prefix — a single scan to the
    /// first star past the cap, no allocation of a filtered copy.
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

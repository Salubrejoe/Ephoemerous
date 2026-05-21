import SwiftUI
import simd

// MARK: - EAppState + Stars
// Star filtering, magnitude caching, selection history, and recently viewed.
// The cache is keyed on (observationDate, origin, magnitudeFilter) — any change
// to those values calls invalidateStarCache(), which is wired up via didSet in EAppState.swift.
extension EAppState {

    // MARK: Cache management

    /// Drop both star caches. Called automatically when observationDate,
    /// magnitudeFilter, or origin changes.
    func invalidateStarCache() {
        _starsCache       = nil
        _travelStarsCache = nil
    }

    // MARK: Filtered star collections

    /// Stars visible above the observer's horizon, filtered by magnitude.
    /// Used in clock mode. Result is cached until the cache is invalidated
    /// (origin / date / magnitude change) — the horizon precess + dot
    /// runs once per rebuild, never per frame.
    var stars: [EStar] {
        if let cached = _starsCache { return cached }
        // Zenith from the *stored* date so the cache key matches the data —
        // `observerZenith` reads `renderedObservationDate`, which can be
        // mid-step during a date transition.
        let lst    = EPrecession.lst(for: observationDate, longitude: origin.longitude)
        let zenith = Angle.spherePoint(latitude: origin.latitude, longitude: lst)
        let result = StarDatabase.shared.workableStars
            .filter { $0.name != "Unknown" && $0.magnitude < magnitudeFilter }
//            .filter { s in
//                let precessed = EPrecession.precess(ra: s.rightAscension, dec: s.declination, to: observationDate)
//                let starVec   = Angle.spherePoint(latitude: precessed.dec, longitude: precessed.ra)
//                return simd_dot(starVec, zenith) > 0.0     // above horizon
//            }
        _starsCache = result
        return result
    }

    /// All named stars filtered by magnitude, without any horizon clipping.
    /// Used in travel mode where the full sky is always visible.
    var travelStars: [EStar] {
        if let cached = _travelStarsCache { return cached }
        let result = StarDatabase.shared.workableStars
            .filter { $0.name != "Unknown" && $0.magnitude < magnitudeFilter }
        _travelStarsCache = result
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

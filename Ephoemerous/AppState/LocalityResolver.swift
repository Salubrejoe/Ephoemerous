import Foundation
import MapKit

// MARK: - LocalityResolver
// Small main-actor singleton that turns a (lat, lon) into a human-
// readable place name via `MKReverseGeocodingRequest`. Apple's
// geocoder is rate-limited (~50 requests/minute/user) so every result
// is cached keyed on the coordinate rounded to 0.1° (~11 km). A slerp
// or a quick map-drag through the same neighbourhood resolves to one
// network request, not one per frame.
//
// The cache is pinned to the main actor — every call site is SwiftUI /
// @Observable state — so no further synchronisation is needed.
@MainActor
final class LocalityResolver {

    static let shared = LocalityResolver()

    private var cache: [String: String] = [:]

    private init() {}

    /// Resolve `(lat, lon)` to a locality name. Returns `cityName`
    /// when available, falling back to `regionName` (country / region)
    /// — or `nil` if the geocoder failed or returned nothing usable.
    /// Open ocean coordinates typically return `nil`.
    func resolve(lat: Double, lon: Double) async -> String? {
        let key = Self.cacheKey(lat: lat, lon: lon)
        if let cached = cache[key] { return cached }

        let location = CLLocation(latitude: lat, longitude: lon)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        do {
            let items = try await request.mapItems
            guard let reps = items.first?.addressRepresentations else { return nil }
            let name = reps.cityName ?? reps.regionName
            if let name { cache[key] = name }
            return name
        } catch {
            return nil
        }
    }

    /// The time zone at `(lat, lon)`, from the same reverse geocoder —
    /// `nil` if it failed (open ocean, offline). Cached like the names.
    func timeZone(lat: Double, lon: Double) async -> TimeZone? {
        let key = Self.cacheKey(lat: lat, lon: lon)
        if let cached = zones[key] { return cached }
        guard let request = MKReverseGeocodingRequest(location: CLLocation(latitude: lat, longitude: lon))
        else { return nil }
        let zone = try? await request.mapItems.first?.timeZone
        if let zone { zones[key] = zone }
        return zone
    }

    private var zones: [String: TimeZone] = [:]

    /// 0.1° rounding ≈ 11 km — coarse enough that movements within a
    /// city all hit the same cache entry, fine enough that a hop
    /// between two nearby cities is a cache miss.
    private static func cacheKey(lat: Double, lon: Double) -> String {
        String(format: "%.1f,%.1f", lat, lon)
    }
}

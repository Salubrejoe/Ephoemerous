import Foundation
import CoreLocation

// MARK: - LocalityResolver
// Small main-actor singleton that turns a (lat, lon) into a human-
// readable place name via `CLGeocoder.reverseGeocodeLocation`. Apple's
// geocoder is rate-limited (~50 requests/minute/user) so every result
// is cached keyed on the coordinate rounded to 0.1° (~11 km). A slerp
// or a quick map-drag through the same neighbourhood resolves to one
// network request, not one per frame.
//
// The cache and the geocoder are pinned to the main actor — every call
// site is SwiftUI / @Observable state — so no further synchronisation
// is needed.
@MainActor
final class LocalityResolver {

    static let shared = LocalityResolver()

    private var cache:    [String: String] = [:]
    private let geocoder: CLGeocoder       = CLGeocoder()

    private init() {}

    /// Resolve `(lat, lon)` to a locality name. Returns the most
    /// specific human-meaningful field available — `locality` (city /
    /// town) → `subAdministrativeArea` (county) → `administrativeArea`
    /// (state / region) → `country` — or `nil` if the geocoder failed
    /// or returned nothing usable. Open ocean coordinates typically
    /// return `nil`.
    func resolve(lat: Double, lon: Double) async -> String? {
        let key = Self.cacheKey(lat: lat, lon: lon)
        if let cached = cache[key] { return cached }

        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let p = placemarks.first else { return nil }
            let name = p.locality
                    ?? p.subAdministrativeArea
                    ?? p.administrativeArea
                    ?? p.country
            if let name { cache[key] = name }
            return name
        } catch {
            return nil
        }
    }

    /// 0.1° rounding ≈ 11 km — coarse enough that movements within a
    /// city all hit the same cache entry, fine enough that a hop
    /// between two nearby cities is a cache miss.
    private static func cacheKey(lat: Double, lon: Double) -> String {
        String(format: "%.1f,%.1f", lat, lon)
    }
}

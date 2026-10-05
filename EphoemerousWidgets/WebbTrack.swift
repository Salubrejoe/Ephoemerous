import Foundation
import simd

// MARK: - WebbTrack
// The JWST's daily track, for the Orloj — fetched by the WIDGET itself:
// the app's spacecraft cache lives in the app's own container, out of the
// widget's reach. Same anonymous Horizons query the app makes (geocentric,
// so where the user stands never leaves the device), cached in the
// widget's caches and refreshed weekly — the table runs a year ahead.
enum WebbTrack {

    /// Refetch once the cached table is older than this. ▼ TWEAK ▼
    static let refreshAge: TimeInterval = 7 * 86_400

    /// The cached table, refreshed first when stale. `nil` offline with
    /// nothing cached — the face simply goes without.
    static func ephemeris() async -> HorizonsEphemeris? {
        if age(of: cacheURL) > refreshAge,
           let id   = Spacecraft.jwst.horizonsID,
           let url  = HorizonsEphemeris.requestURL(horizonsID: id, around: .now),
           let (data, response) = try? await URLSession.shared.data(from: url),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let text = String(data: data, encoding: .utf8),
           HorizonsEphemeris.parse(text) != nil {
            try? data.write(to: cacheURL, options: .atomic)
        }
        guard let data = try? Data(contentsOf: cacheURL),
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return HorizonsEphemeris.parse(text)
    }

    private static let cacheURL: URL = {
        let dir = URL.cachesDirectory.appending(path: "Spacecraft", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "jwst.txt")
    }()

    private static func age(of file: URL) -> TimeInterval {
        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return modified.map { -$0.timeIntervalSinceNow } ?? .infinity
    }
}

import Foundation

// MARK: - Constellation categories
// Cultural / mythological metadata for every IAU constellation,
// loaded once from `constellation_categories.json` and exposed via
// `ConstellationCategories.shared.category(for:)`.
//
// JSON shape (one entry per constellation):
//
//   {"abbr":"And","name":"Andromeda",
//    "myths":["perseus"],"types":["hero"],"origin":"ptolemy"}
//
// Axes:
//   • myths  — mythological cycle(s) the figure belongs to
//              (perseus, hercules, argo, zeus, orion, orpheus).
//              A figure can sit in several cycles; the first is
//              treated as the primary entity for POI badge
//              tinting. The former `zodiac` value is gone — the
//              zodiac is a band of sky, not a myth; each zodiac
//              constellation lives in its own cycle now (e.g.
//              Aries → argo, Aquarius → zeus, Scorpius → orion).
//   • types  — what the constellation depicts (hero, animal,
//              creature, object, instrument, deity).
//   • origin — who first catalogued it (ptolemy, lacaille,
//              bayer, hevelius, other).
//
// `Artist.constellationEntity(of:)` reads `myths.first` from
// here to colour each constellation POI badge.
final class ConstellationCategories {

    static let shared = ConstellationCategories()

    private let byConstellation: [Constellation: Entry]

    /// One JSON entry, mirroring the file shape verbatim.
    struct Entry: Decodable {
        let abbr:   String
        let name:   String
        let myths:  [String]
        let types:  [String]
        let origin: String
    }

    private init() {
        let raw = Self.loadRaw()
        var index: [Constellation: Entry] = [:]
        index.reserveCapacity(raw.count)
        for entry in raw {
            if let cons = Constellation(rawValue: entry.abbr) {
                index[cons] = entry
            }
        }
        self.byConstellation = index
    }

    /// Look up the JSON entry for `cons`, or `nil` if it's not
    /// listed (shouldn't happen for the 88 IAU constellations).
    func category(for cons: Constellation) -> Entry? {
        byConstellation[cons]
    }

    // MARK: - Loading

    private static func loadRaw() -> [Entry] {
        guard let url = Bundle.main.url(
            forResource: "constellation_categories",
            withExtension: "json"
        ) else {
            Logger.constellationLines("constellation_categories.json not found in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            Logger.constellationLines("constellation_categories decode failed: \(error)")
            return []
        }
    }
}

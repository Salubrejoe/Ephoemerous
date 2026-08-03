import Foundation

// MARK: - Constellation catasterism
// "How it reached the sky" — the warm placement line for each storied
// constellation, loaded from `constellation_catasterism.json` and keyed by
// IAU abbreviation. This is the emotional grounding the myth storyteller
// (Foundation Models) builds on: the catasterism is fed verbatim so the
// model retells *this* placement rather than inventing one.
//
// Coverage is the STORIED set only (Ptolemaic figures + the myth-tagged
// ones). Modern constellations (Lacaille / Bayer / Hevelius) have no
// sky-placement myth — `catasterism(for:)` returns nil for them, and the
// storyteller falls back to their `origin` ("named by … to chart the
// southern sky"). See `ConstellationCategories.origin`.
//
// PLACEHOLDER COPY: these lines are first-draft, to be curated. Keep them
// short, warm, and accurate to the canonical catasterism.
//
// JSON shape: [{"abbr":"Ori","catasterism":"…"}]
final class ConstellationCatasterism {

    static let shared = ConstellationCatasterism()

    private let byConstellation: [Constellation: String]

    private struct Entry: Decodable {
        let abbr:        String
        let catasterism: String
    }

    private init() {
        let raw = Self.loadRaw()
        var index: [Constellation: String] = [:]
        index.reserveCapacity(raw.count)
        for entry in raw {
            if let cons = Constellation(rawValue: entry.abbr) {
                index[cons] = entry.catasterism
            }
        }
        self.byConstellation = index
    }

    /// The catasterism line for `cons`, or `nil` for constellations with no
    /// sky-placement myth (the modern ones).
    func catasterism(for cons: Constellation) -> String? {
        byConstellation[cons]
    }

    // MARK: - Loading

    private static func loadRaw() -> [Entry] {
        guard let url = Bundle.main.url(
            forResource: "constellation_catasterism",
            withExtension: "json"
        ) else {
            Logger.constellationLines("constellation_catasterism.json not found in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            Logger.constellationLines("constellation_catasterism decode failed: \(error)")
            return []
        }
    }
}

import Foundation
import simd
import SwiftUI


// MARK: - ConstellationLines
// Loads the static `constellationLines.json` bundle resource once and
// resolves every segment into a concrete `(EStar, EStar)` pair against
// `StarDatabase`. Pairs whose stars are absent from BSC are silently
// dropped — the layer just won't draw them.
//
// The JSON is keyed by constellation IAU abbreviation (matching
// `EConstellation.rawValue`) and each value is an array of two-element
// designation pairs. A designation is either a Greek-letter Bayer
// abbreviation (`"Alp"`, `"Bet"`, …) or a Flamsteed number (`"21"`).
// The resolver tries Bayer first (via the Greek-symbol form already
// baked into `EStar.name`), then falls back to Flamsteed.
final class ConstellationLines {

    static let shared = ConstellationLines()

    /// Resolved segments, keyed by constellation.
    let segments: [EConstellation: [Segment]]

    /// Label anchor (RA, Dec) per constellation — vector centroid of the
    /// figure-stars on the unit sphere, projected back to spherical
    /// coordinates. Empty when a constellation has no resolved segments.
    let labelAnchors: [EConstellation: (ra: Angle, dec: Angle)]

    struct Segment {
        let a: EStar
        let b: EStar
    }

    private init() {
        let raw = Self.loadRaw()
        var resolved: [EConstellation: [Segment]] = [:]
        var anchors:  [EConstellation: (ra: Angle, dec: Angle)] = [:]

        let stars = StarDatabase.shared.workableStars
        let index = Self.buildIndex(stars: stars)

        for (key, pairs) in raw {
            guard let cons = EConstellation(rawValue: key) else { continue }
            var segs: [Segment] = []
            var figureStars: [EStar] = []

            for pair in pairs where pair.count == 2 {
                guard let sa = Self.resolve(designation: pair[0], in: cons, using: index),
                      let sb = Self.resolve(designation: pair[1], in: cons, using: index)
                else { continue }
                segs.append(Segment(a: sa, b: sb))
                figureStars.append(sa)
                figureStars.append(sb)
            }

            guard !segs.isEmpty else { continue }
            resolved[cons] = segs
            anchors[cons]  = Self.centroid(of: figureStars)
        }

        self.segments     = resolved
        self.labelAnchors = anchors
        ELogger.constellationLines("loaded \(resolved.count) constellations, \(resolved.values.reduce(0) { $0 + $1.count }) segments")
    }

    // MARK: - Loading

    private static func loadRaw() -> [String: [[String]]] {
        guard let url = Bundle.main.url(forResource: "constellationLines", withExtension: "json") else {
            ELogger.constellationLines("constellationLines.json not found in bundle")
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: [[String]]].self, from: data)
        } catch {
            ELogger.constellationLines("decode failed: \(error)")
            return [:]
        }
    }

    // MARK: - Lookup index

    /// Per-constellation dictionary keyed by designation → star.
    /// Designations are stored both as Greek symbols (Bayer) and as
    /// Flamsteed-number strings, so a single lookup handles either form.
    private typealias Index = [EConstellation: [String: EStar]]

    private static func buildIndex(stars: [EStar]) -> Index {
        var idx: Index = [:]
        for star in stars {
            let cons = star.constellation
            guard cons != .none else { continue }
            // `EStar.name` is e.g. "21 α And", "α And", or "21 And".
            // Drop the trailing constellation token then split.
            let stripped = star.name
                .replacingOccurrences(of: " \(cons.rawValue)", with: "")
                .trimmingCharacters(in: .whitespaces)
            let tokens = stripped.split(separator: " ").map(String.init)
            var bucket = idx[cons] ?? [:]
            for token in tokens {
                // Each token is either a Flamsteed number or a Greek glyph.
                // First write wins so brightest-listed BSC entry is kept
                // when a designation appears multiple times (e.g. α¹ Cen).
                if bucket[token] == nil { bucket[token] = star }
            }
            idx[cons] = bucket
        }
        return idx
    }

    private static func resolve(designation: String, in cons: EConstellation, using index: Index) -> EStar? {
        guard let bucket = index[cons] else { return nil }
        // Try Greek-symbol form first (Bayer); fall back to raw designation
        // (Flamsteed number or already-Greek glyph).
        if let glyph = bayerGreek[designation], let star = bucket[glyph] { return star }
        return bucket[designation]
    }

    private static let bayerGreek: [String: String] = [
        "Alp": "α", "Bet": "β", "Gam": "γ", "Del": "δ", "Eps": "ε",
        "Zet": "ζ", "Eta": "η", "The": "θ", "Iot": "ι", "Kap": "κ",
        "Lam": "λ", "Mu" : "μ", "Nu" : "ν", "Xi" : "ξ", "Omi": "ο",
        "Pi" : "π", "Rho": "ρ", "Sig": "σ", "Tau": "τ", "Ups": "υ",
        "Phi": "φ", "Chi": "χ", "Psi": "ψ", "Ome": "ω",
    ]

    // MARK: - Centroid

    /// Vector mean on the unit sphere → back to spherical. Robust to the
    /// 0h/24h RA seam (Andromeda, Pisces, Pegasus, Cetus) that bites any
    /// naïve scalar average.
    private static func centroid(of stars: [EStar]) -> (ra: Angle, dec: Angle) {
        var v = SIMD3<Double>(repeating: 0)
        for s in stars {
            let ra  = s.rightAscension.radians
            let dec = s.declination.radians
            let cd  = cos(dec)
            v += SIMD3(cd * cos(ra), cd * sin(ra), sin(dec))
        }
        let n = simd_length(v)
        guard n > 1e-9 else { return (.zero, .zero) }
        v /= n
        let dec = asin(v.z)
        let ra  = atan2(v.y, v.x)
        return (.radians(ra >= 0 ? ra : ra + 2 * .pi), .radians(dec))
    }
}

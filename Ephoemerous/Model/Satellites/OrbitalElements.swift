import Foundation

// MARK: - OrbitalElements
// One CelesTrak general-perturbations element set, decoded straight from
// its OMM JSON (`gp.php?CATNR=…&FORMAT=json`). The field names are the
// CCSDS OMM keywords, so the coding keys read like the wire format. Angles
// arrive in degrees and mean motion in revolutions per day — the SGP4
// initialiser converts to radians and radians-per-minute itself.
nonisolated struct OrbitalElements: Codable, Equatable, Sendable {

    let name:            String
    let noradID:         Int
    let epoch:           Date
    let meanMotion:      Double   // rev / day (Kozai)
    let eccentricity:    Double
    let inclination:     Double   // deg
    let ascendingNode:   Double   // deg
    let argOfPericenter: Double   // deg
    let meanAnomaly:     Double   // deg
    let bstar:           Double   // 1 / earth radii

    enum CodingKeys: String, CodingKey {
        case name            = "OBJECT_NAME"
        case noradID         = "NORAD_CAT_ID"
        case epoch           = "EPOCH"
        case meanMotion      = "MEAN_MOTION"
        case eccentricity    = "ECCENTRICITY"
        case inclination     = "INCLINATION"
        case ascendingNode   = "RA_OF_ASC_NODE"
        case argOfPericenter = "ARG_OF_PERICENTER"
        case meanAnomaly     = "MEAN_ANOMALY"
        case bstar           = "BSTAR"
    }

    /// Orbital period in minutes — SGP4 (near-Earth) is only valid below
    /// 225; anything slower needs the deep-space SDP4 terms we don't carry.
    var periodMinutes: Double { 1440 / meanMotion }

    /// How far a date sits from the element epoch, in minutes — the `t`
    /// SGP4 propagates by.
    func minutesSinceEpoch(_ date: Date) -> Double {
        date.timeIntervalSince(epoch) / 60
    }
}

// MARK: - Decoding

nonisolated extension OrbitalElements {

    /// CelesTrak's EPOCH is ISO-8601 without a zone ("2026-09-27T22:06:54.348768"),
    /// always UTC, with up to microseconds — more digits than
    /// `ISO8601DateFormatter` accepts, so the fraction is split off by hand.
    static func parseEpoch(_ text: String) -> Date? {
        let parts = text.split(separator: ".", maxSplits: 1)
        let whole = epochFormatter.date(from: String(parts[0]))
        let frac  = parts.count > 1 ? Double("0." + parts[1]) ?? 0 : 0
        return whole?.addingTimeInterval(frac)
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseEpoch(text) else {
                throw DecodingError.dataCorrupted(.init(codingPath:        decoder.codingPath,
                                                        debugDescription: "Bad OMM epoch \(text)"))
            }
            return date
        }
        return d
    }()

    private static let epochFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()
}

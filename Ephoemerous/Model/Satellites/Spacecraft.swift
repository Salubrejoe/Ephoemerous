import Foundation

// MARK: - Spacecraft
// The crafted things we follow across the sky. Three ride low Earth orbit
// (the two crewed stations and Hubble) and are propagated on-device from
// CelesTrak element sets; JWST sits a
// million and a half kilometres out at L2, where "orbit elements" stop
// meaning anything useful, so it reads its place off a JPL Horizons table.
nonisolated enum Spacecraft: String, CaseIterable, Identifiable, Hashable, Sendable {
    case iss
    case hubble
    case jwst
    case tiangong

    var id: String { rawValue }

    /// NORAD catalogue number for the CelesTrak fetch; nil when the craft
    /// isn't in Earth orbit.
    var noradID: Int? {
        switch self {
        case .iss:    return 25_544
        case .hubble: return 20_580
        case .jwst:   return nil
        case .tiangong: return 48_274    // CSS (Tianhe core)
        }
    }

    /// JPL Horizons target id, for the craft Horizons tabulates instead.
    var horizonsID: String? {
        self == .jwst ? "-170" : nil
    }

    /// Magnitude at 1000 km, half-lit (the McCants / Heavens-Above
    /// convention `SatelliteSky.magnitude` scales from).
    var standardMagnitude: Double {
        switch self {
        case .iss:    return -1.8
        case .hubble: return  2.0
        case .jwst:   return 16      // never a naked-eye object
        case .tiangong: return -1.0  // second only to the ISS
        }
    }

    var displayName: String {
        switch self {
        case .iss:    return String(localized: "ISS",    comment: "International Space Station, short name")
        case .hubble: return String(localized: "Hubble", comment: "Hubble Space Telescope, short name")
        case .jwst:   return String(localized: "Webb",   comment: "James Webb Space Telescope, short name")
        case .tiangong: return String(localized: "Tiangong", comment: "Chinese space station, short name")
        }
    }

    var fullName: String {
        switch self {
        case .iss:    return String(localized: "International Space Station", comment: "Spacecraft full name")
        case .hubble: return String(localized: "Hubble Space Telescope",      comment: "Spacecraft full name")
        case .jwst:   return String(localized: "James Webb Space Telescope",  comment: "Spacecraft full name")
        case .tiangong: return String(localized: "Tiangong Space Station",    comment: "Spacecraft full name")
        }
    }

    var isInEarthOrbit: Bool { noradID != nil }
}

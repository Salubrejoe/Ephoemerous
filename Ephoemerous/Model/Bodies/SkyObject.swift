import Foundation

// MARK: - Unified sky object for list navigation

enum SkyObject: Identifiable, Hashable {
    case star(Star)
    case sun
    case moon
    case planet(Planet)
    case constellation(Constellation)

    var id: String {
        switch self {
        case .star(let s):          return "star_\(s.id)"
        case .sun:                  return "sun"
        case .moon:                 return Strings.SearchTokens.moonToken
        case .planet(let p):        return "planet_\(p.id)"
        case .constellation(let c): return "constellation_\(c.rawValue)"
        }
    }

    var displayName: String {
        switch self {
        case .star(let s):          return s.displayName
        case .sun:                  return String(localized: "Sun")
        case .moon:                 return String(localized: "Moon")
        case .planet(let p):        return p.displayName
        case .constellation(let c): return c.localizedName
        }
    }

    var searchTokens: String {
        switch self {
        case .star(let s):
            return "\(s.displayName) \(s.constellation.fullName) \(s.spectralClass.rawValue)".lowercased()
        case .sun:
            return "sun solar g-type star"
        case .moon:
            return Strings.SearchTokens.moonFullToken
        case .planet(let p):
            // Match on both the English identity and the localised name so
            // search works whatever the device language.
            return "\(p.name) \(p.displayName) planet".lowercased()
        case .constellation(let c):
            return "\(c.localizedName) \(c.fullName) \(c.rawValue) constellation".lowercased()
        }
    }
}

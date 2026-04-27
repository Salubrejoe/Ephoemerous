import Foundation

// MARK: - Unified sky object for list navigation

enum ESkyObject: Identifiable, Hashable {
    case star(EStar)
    case sun
    case moon
    case planet(EPlanet)
    case constellation(EConstellation)

    var id: String {
        switch self {
        case .star(let s):          return "star_\(s.id)"
        case .sun:                  return "sun"
        case .moon:                 return "moon"
        case .planet(let p):        return "planet_\(p.id)"
        case .constellation(let c): return "constellation_\(c.rawValue)"
        }
    }

    var displayName: String {
        switch self {
        case .star(let s):          return s.displayName
        case .sun:                  return "Sun"
        case .moon:                 return "Moon"
        case .planet(let p):        return p.name
        case .constellation(let c): return c.fullName
        }
    }

    var searchTokens: String {
        switch self {
        case .star(let s):
            return "\(s.displayName) \(s.constellation.fullName) \(s.spectralClass.rawValue)".lowercased()
        case .sun:
            return "sun solar g-type star"
        case .moon:
            return "moon lunar satellite"
        case .planet(let p):
            return "\(p.name) planet".lowercased()
        case .constellation(let c):
            return "\(c.fullName) \(c.rawValue) constellation".lowercased()
        }
    }
}

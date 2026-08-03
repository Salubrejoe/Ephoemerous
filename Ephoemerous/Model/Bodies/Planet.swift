import SwiftUI

// MARK: - Planet model (moved from ENSPlanetsLayer)

struct Planet: Identifiable, Hashable {
    let name:          String
    let color:         Color
    /// Approximate visual magnitude at mean distance
    let baseMagnitude: Double
    /// SF Symbol name for list display
    var symbol:        String { "circle.fill" }

    var id: String { name }

    /// Localised, user-facing name. `name` stays the canonical English
    /// identity (Palette / PlanetFacts switch keys, CloudKit favourites,
    /// `id`); this is the only thing that should ever be shown on screen.
    /// This is the "separate display layer" the `Strings.Planets` comment
    /// deferred. Keys mirror the English identity so the String Catalog
    /// extracts them cleanly.
    var displayName: String {
        switch name {
        case Strings.Planets.mercury: return String(localized: "Mercury", comment: "Planet name")
        case Strings.Planets.venus:   return String(localized: "Venus",   comment: "Planet name")
        case Strings.Planets.mars:    return String(localized: "Mars",    comment: "Planet name")
        case Strings.Planets.jupiter: return String(localized: "Jupiter", comment: "Planet name")
        case Strings.Planets.saturn:  return String(localized: "Saturn",  comment: "Planet name")
        case Strings.Planets.uranus:  return String(localized: "Uranus",  comment: "Planet name")
        case Strings.Planets.neptune: return String(localized: "Neptune", comment: "Planet name")
        default:                      return name
        }
    }

    // Hashable / Equatable by name only
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
    static func == (lhs: Planet, rhs: Planet) -> Bool { lhs.name == rhs.name }

    // MARK: - All 7 planets (canonical, shared by layer + list)
    static let mercury = Planet(name: Strings.Planets.mercury, color: .gray,                             baseMagnitude: -0.5)
    static let venus   = Planet(name: Strings.Planets.venus,   color: Color(red:1,   green:0.97, blue:0.85), baseMagnitude: -4.0)
    static let mars    = Planet(name: Strings.Planets.mars,    color: Color(red:1,   green:0.35, blue:0.2),  baseMagnitude: -2.0)
    static let jupiter = Planet(name: Strings.Planets.jupiter, color: Color(red:1,   green:0.87, blue:0.7),  baseMagnitude: -2.5)
    static let saturn  = Planet(name: Strings.Planets.saturn,  color: Color(red:0.95,green:0.87, blue:0.6),  baseMagnitude:  0.7)
    static let uranus  = Planet(name: Strings.Planets.uranus,  color: Color(red:0.6, green:0.9,  blue:0.95), baseMagnitude:  5.7)
    static let neptune = Planet(name: Strings.Planets.neptune, color: Color(red:0.4, green:0.55, blue:1.0),  baseMagnitude:  8.0)

    static let all: [Planet] = [mercury, venus, mars, jupiter, saturn, uranus, neptune]
}

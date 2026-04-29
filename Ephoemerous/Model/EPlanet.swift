import SwiftUI

// MARK: - Planet model (moved from ENSPlanetsLayer)

struct EPlanet: Identifiable, Hashable {
    let name:          String
    let color:         Color
    /// Approximate visual magnitude at mean distance
    let baseMagnitude: Double
    /// SF Symbol name for list display
    var symbol:        String { "circle.fill" }

    var id: String { name }

    // Hashable / Equatable by name only
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
    static func == (lhs: EPlanet, rhs: EPlanet) -> Bool { lhs.name == rhs.name }

    // MARK: - All 7 planets (canonical, shared by layer + list)
    static let mercury = EPlanet(name: Strings.Planets.mercury, color: .gray,                             baseMagnitude: -0.5)
    static let venus   = EPlanet(name: Strings.Planets.venus,   color: Color(red:1,   green:0.97, blue:0.85), baseMagnitude: -4.0)
    static let mars    = EPlanet(name: Strings.Planets.mars,    color: Color(red:1,   green:0.35, blue:0.2),  baseMagnitude: -2.0)
    static let jupiter = EPlanet(name: Strings.Planets.jupiter, color: Color(red:1,   green:0.87, blue:0.7),  baseMagnitude: -2.5)
    static let saturn  = EPlanet(name: Strings.Planets.saturn,  color: Color(red:0.95,green:0.87, blue:0.6),  baseMagnitude:  0.7)
    static let uranus  = EPlanet(name: Strings.Planets.uranus,  color: Color(red:0.6, green:0.9,  blue:0.95), baseMagnitude:  5.7)
    static let neptune = EPlanet(name: Strings.Planets.neptune, color: Color(red:0.4, green:0.55, blue:1.0),  baseMagnitude:  8.0)

    static let all: [EPlanet] = [mercury, venus, mars, jupiter, saturn, uranus, neptune]
}

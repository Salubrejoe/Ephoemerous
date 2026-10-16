import Foundation

// MARK: - Nebula facts
// What a nebula's card says about it — Wikipedia and NASA, October 2026.
// The catalogue's own distances (Gaia parallaxes of the central stars) are
// kept where it has one: the Ring, the Owl, the Dumbbell. The rest are the
// published figures, the Orion Nebula's from VLBA radio parallax; De
// Mairan's is the same cloud, so it takes the same distance.
extension NamedNebula {

    /// Light-years from us, where the catalogue holds none.
    var publishedDistanceLy: Double? {
        switch self {
        case .orion, .deMairan: return 1_344
        case .m78:              return 1_350
        case .littleDumbbell:   return 2_500
        case .lagoon:           return 4_100
        case .carina:           return 8_500
        case .ring, .owl, .dumbbell: return nil
        }
    }

    enum Kind { case planetary, emission, reflection }

    var kind: Kind {
        switch self {
        case .ring, .owl, .dumbbell, .littleDumbbell: return .planetary
        case .orion, .deMairan, .carina, .lagoon:     return .emission
        case .m78:                                    return .reflection
        }
    }

    /// The kind, in words — the card's subtitle leads with it.
    var kindName: String {
        switch kind {
        case .planetary:  return String(localized: "Planetary nebula")
        case .emission:   return String(localized: "Emission nebula")
        case .reflection: return String(localized: "Reflection nebula")
        }
    }

    /// Where it is in a star's life.
    var story: String {
        kind == .planetary ? String(localized: "A star's last breath")
                           : String(localized: "Stars being born")
    }

    /// How its light is made.
    var shinesBy: String {
        kind == .reflection ? String(localized: "Dust reflecting starlight")
                            : String(localized: "Its own glowing gas")
    }

    /// The star or stars that light it.
    var litBy: String {
        switch self {
        case .ring, .owl, .dumbbell, .littleDumbbell:
            return String(localized: "A white dwarf at its heart")
        case .orion:    return String(localized: "The Trapezium")
        case .deMairan: return String(localized: "NU Orionis")
        case .m78:      return String(localized: "Two young blue stars")
        case .carina:   return String(localized: "Eta Carinae and its clusters")
        case .lagoon:   return String(localized: "9 Sagittarii and Herschel 36")
        }
    }

    /// Its catalogue entry, for the roster and its own card.
    var object: DeepSkyObject? { DeepSkyCatalog.objects.first { $0.id == rawValue } }
}

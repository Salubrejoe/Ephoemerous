import Foundation

// MARK: - Galaxy facts
// What a galaxy's card says about it — Wikipedia's infoboxes, October 2026.
// Distances and sizes are the D25 diameters (out to where the galaxy fades
// to 25 mag per square arcsecond), the same measure for all six and for
// the Milky Way they're compared with. Star counts only where they're
// published; M32's and M110's aren't.
extension LocalGalaxy {

    /// The Milky Way's D25 diameter, the yardstick every size is held to.
    static let milkyWayDiameterLy: Double = 87_400

    /// Light-years from us.
    var distanceLy: Double {
        switch self {
        case .lmc:        return 163_000
        case .smc:        return 203_700
        case .m32:        return 2_490_000
        case .andromeda:  return 2_500_000
        case .m110:       return 2_690_000
        case .triangulum: return 2_880_000
        }
    }

    /// Light-years across.
    var diameterLy: Double {
        switch self {
        case .andromeda:  return 152_000
        case .triangulum: return 61_120
        case .lmc:        return 32_200
        case .smc:        return 18_900
        case .m110:       return 17_050
        case .m32:        return 8_000
        }
    }

    /// The kind, in words — the card's subtitle leads with it.
    var kindName: String {
        switch self {
        case .andromeda:  return String(localized: "Barred spiral galaxy")
        case .triangulum: return String(localized: "Spiral galaxy")
        case .m32:        return String(localized: "Compact elliptical galaxy")
        case .m110:       return String(localized: "Dwarf elliptical galaxy")
        case .lmc:        return String(localized: "Magellanic spiral galaxy")
        case .smc:        return String(localized: "Dwarf irregular galaxy")
        }
    }

    /// Its Hubble–de Vaucouleurs class, for those who read them.
    var morphology: String {
        switch self {
        case .andromeda:  return "SAB(s)b"
        case .triangulum: return "SA(s)cd"
        case .m32:        return "cE2"
        case .m110:       return "E5 pec"
        case .lmc:        return "SB(s)m"
        case .smc:        return "SB(s)m pec"
        }
    }

    var stars: String? {
        switch self {
        case .andromeda:  return String(localized: "About a trillion")
        case .triangulum: return String(localized: "About 40 billion")
        case .lmc:        return String(localized: "About 20 billion")
        case .smc:        return String(localized: "About 3 billion")
        case .m32, .m110: return nil
        }
    }

    /// What it circles, where it's a satellite.
    var orbits: String? {
        switch self {
        case .m32, .m110: return String(localized: "Andromeda")
        case .lmc, .smc:  return String(localized: "The Milky Way")
        case .andromeda, .triangulum: return nil
        }
    }

    /// Its place in the Local Group, where it's notable.
    var standing: String? {
        switch self {
        case .andromeda:  return String(localized: "The largest")
        case .triangulum: return String(localized: "Third largest")
        default:          return nil
        }
    }

    /// A short name for tight spots — the distance line.
    var shortName: String {
        switch self {
        case .andromeda:  return String(localized: "Andromeda")
        case .triangulum: return String(localized: "Triangulum")
        case .m32:        return "M32"
        case .m110:       return "M110"
        case .lmc:        return String(localized: "LMC")
        case .smc:        return String(localized: "SMC")
        }
    }

    /// Its catalogue entry, for the neighbours list and its own card.
    var object: DeepSkyObject? { DeepSkyCatalog.objects.first { $0.id == rawValue } }
}

extension DeepSkyObject {
    /// Light-years away: the catalogue's own figure, or for a galaxy or a
    /// named nebula its published distance, where the catalogue holds none.
    var lightYears: Double? { distance ?? galaxy?.distanceLy ?? namedNebula?.publishedDistanceLy }
}

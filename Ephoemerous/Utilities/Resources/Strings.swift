import Foundation

// MARK: - Strings
// Centralised user-facing copy, ready to be localised in one pass (the
// String Catalog migration is the next phase). This table holds ONLY
// translatable text + format specifiers — never:
//   • SF Symbol names  → LoreSymbol / ESymbol
//   • config identifiers (bundle / group / iCloud container) → project
//     settings + entitlements, which are the real source of truth
//   • hardcoded astronomical data → the detail views compute it live
struct Strings {

    // MARK: - Sort & Filter
    struct Sort {
        static let constellation = "Constellation"
        static let brighterThan  = "Brighter than"
        static let magnitude     = "Magnitude"
        static let name          = "Name"
        static let sortBy        = "Sort by"
    }
    
    // MARK: - Prompts
    struct Prompts {
        static let searchBar   = "Search, remember..."
        static let searchBar2  = "Name, constellation, class..."
    }
    
    // MARK: - Titles
    enum Titles: String {
        case allStars       = "All Stars"
        case constellations = "Constellations"
        case listTitle      = "Ephemerous"
        case magnFilter     = "Magnitude filter"
        case moon           = "Moon"
        case recentlyViewed = "Recently Viewed"
        case solarSystem    = "Solar System"
        case sortNFilter    = "Sort & Filter"
        case stars          = "Stars"
        case sun            = "Sun"
    }
    
    // MARK: - Actions
    struct Actions {
        static let save    = "Save"
        static let cancel  = "Cancel"
        static let delete  = "Delete"
        static let edit    = "Edit"
        static let done    = "Done"
        static let add     = "Add"
        static let confirm = "Confirm"
        static let retry   = "Retry"
    }
    
    struct Format {
        static let magnFormat         = "%.1f mag"
    }
    
    // MARK: - Fallback
    struct Fallback {
        static let empty                = ""
        static let unknown              = "--"
    }

    // MARK: - Sky Bodies
    struct Bodies {
        static let sun              = "Sun"
        static let moon             = "Moon"
    }

    // MARK: - Body Detail Labels
    struct BodyDetail {
        // Shared section titles
        static let coordinates      = "Coordinates"
        static let physical         = "Physical"
        static let properMotion     = "Proper Motion"
        // Coordinate rows
        static let rightAscension   = "Right Ascension"
        static let declination      = "Declination"
        static let eclipticLon      = "Ecliptic longitude"
        // Physical rows
        static let distance         = "Distance"
        static let magnitude        = "Magnitude"
        static let spectralClass    = "Spectral Class"
        static let constellation    = "Constellation"
        static let bayer            = "Bayer"
        static let type             = "Type"
        static let temperature      = "Temperature"
        static let radius           = "Radius"
        static let diameter         = "Diameter"
        static let period           = "Period"
        // Sun events
        static let sunEvents        = "Sun Events"
        static let civilDawn        = "Civil Dawn"
        static let sunrise          = "Sunrise"
        static let solarNoon        = "Solar Noon"
        static let sunset           = "Sunset"
        static let civilDusk        = "Civil Dusk"
        // Moon events
        static let moonEvents       = "Moon Events"
        static let moonPhase        = "Phase"
        static let moonrise         = "Moonrise"
        static let moonset          = "Moonset"
        static let illumination     = "Illumination"
        // Proper motion rows
        static let pmRA             = "RA  (mas/yr)"
        static let pmDec            = "Dec (mas/yr)"
    }

    // MARK: - Weather / Loading states
    struct Weather {
        static let fetching         = "Fetching..."
        static let unavailable      = "Unavailable"
        static let error            = "Error"
    }

    // MARK: - Location
    struct Location {
        static let atYourLocation       = "At your location"
        static let centreOnLocation     = "Centre on your location"
        static let acquiringLocation    = "Acquiring location..."
        static let tapToEnable          = "Tap to enable location"
        static let accessDenied         = "Location access denied"
    }

    // MARK: - Detail format strings
    struct DetailFormat {
        static let distanceLY       = "%.1f ly"
        static let magnitude        = "%.2f"
        static let illuminationPct  = "%.1f%%"
        static let raHours          = "%.2fh"
        static let decDeg           = "%+.2f°"
        static let eclipticLonDeg   = "%.3f°"
        static let magLabel         = "mag %.2f"
        static let distanceLabel    = "%.0f ly"
    }

    // MARK: - Star list footer
    struct StarList {
        static func starsShown(_ count: Int) -> String { "\(count) stars shown" }
    }


    // MARK: - Planets
    struct Planets {
        static let mercury        = "Mercury"
        static let venus          = "Venus"
        static let mars           = "Mars"
        static let jupiter        = "Jupiter"
        static let saturn         = "Saturn"
        static let uranus         = "Uranus"
        static let neptune        = "Neptune"
        static let solarPlanet    = "Solar system planet"
        static let meanMagnitude  = "Mean magnitude"
    }
    // MARK: - Moon phases
    struct MoonPhase {
        static let newMoon        = "New Moon"
        static let waxingCrescent = "Waxing Crescent"
        static let firstQuarter   = "First Quarter"
        static let waxingGibbous  = "Waxing Gibbous"
        static let fullMoon       = "Full Moon"
        static let waningGibbous  = "Waning Gibbous"
        static let lastQuarter    = "Last Quarter"
        static let waningCrescent = "Waning Crescent"
        static let unknown        = "New Moon"  // fallback
    }
    // MARK: - Constellation detail
    struct ConstellationDetail {
        static let identity       = "Identity"
        static let abbreviation   = "Abbreviation"
        static let fullName       = "Full name"
        static let zodiac         = "Zodiac"
    }
    // MARK: - Preset names
    struct Preset {
        static let morning        = "Morning"
        static let day            = "Day"
        static let afternoon      = "Afternoon"
        static let night          = "Night"
        static let trackSun       = "Track Sun"
        static let trackMoon      = "Track Moon"
        static let trackStar      = "Track Star"
        static let defaultPreset  = "Default"
    }
    // MARK: - Search tokens
    struct SearchTokens {
        static let moonToken      = "moon"
        static let moonFullToken  = "moon lunar satellite"
    }
}

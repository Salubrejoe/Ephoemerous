import Foundation

// MARK: - Strings
// Centralised user-facing copy. This table holds ONLY translatable text +
// format specifiers — never:
//   • SF Symbol names  → LoreSymbol / Symbol
//   • config identifiers (bundle / group / iCloud container) → project
//     settings + entitlements, which are the real source of truth
//   • hardcoded astronomical data → the detail views compute it live
//
// Localisation: display copy is wrapped in `String(localized:)` so the
// English literal doubles as the String Catalog key (auto-extracted into
// Localizable.xcstrings on build). A few entries are deliberately NOT
// localised because they're used as *identity*, not display — see the
// "Canonical (not localised)" section at the bottom.
struct Strings {

    // MARK: - Sort & Filter
    struct Sort {
        static let constellation = String(localized: "Constellation")
        static let brighterThan  = String(localized: "Brighter than")
        static let magnitude     = String(localized: "Magnitude")
        static let name          = String(localized: "Name")
        static let sortBy        = String(localized: "Sort by")
    }

    // MARK: - Prompts
    struct Prompts {
        static let searchBar   = String(localized: "Search, remember...")
        static let searchBar2  = String(localized: "Name, constellation, class...")
    }

    // MARK: - Titles
    struct Titles {
        static let allStars       = String(localized: "All Stars")
        static let constellations = String(localized: "Constellations")
        static let listTitle      = String(localized: "Ephemerous")
        static let magnFilter     = String(localized: "Magnitude filter")
        static let moon           = String(localized: "Moon")
        static let recentlyViewed = String(localized: "Recently Viewed")
        static let solarSystem    = String(localized: "Solar System")
        static let sortNFilter    = String(localized: "Sort & Filter")
        static let stars          = String(localized: "Stars")
        static let sun            = String(localized: "Sun")
    }

    // MARK: - Actions
    struct Actions {
        static let save    = String(localized: "Save")
        static let cancel  = String(localized: "Cancel")
        static let delete  = String(localized: "Delete")
        static let edit    = String(localized: "Edit")
        static let done    = String(localized: "Done")
        static let add     = String(localized: "Add")
        static let confirm = String(localized: "Confirm")
        static let retry   = String(localized: "Retry")
    }

    // MARK: - Sky Bodies
    struct Bodies {
        static let sun  = String(localized: "Sun")
        static let moon = String(localized: "Moon")
    }

    // MARK: - Body Detail Labels
    struct BodyDetail {
        // Shared section titles
        static let coordinates      = String(localized: "Coordinates")
        static let physical         = String(localized: "Physical")
        static let properMotion     = String(localized: "Proper Motion")
        // Coordinate rows
        static let rightAscension   = String(localized: "Right Ascension")
        static let declination      = String(localized: "Declination")
        static let eclipticLon      = String(localized: "Ecliptic longitude")
        // Physical rows
        static let distance         = String(localized: "Distance")
        static let magnitude        = String(localized: "Magnitude")
        static let spectralClass    = String(localized: "Spectral Class")
        static let constellation    = String(localized: "Constellation")
        static let bayer            = String(localized: "Bayer")
        static let type             = String(localized: "Type")
        static let temperature      = String(localized: "Temperature")
        static let radius           = String(localized: "Radius")
        static let diameter         = String(localized: "Diameter")
        static let period           = String(localized: "Period")
        // Sun events
        static let sunEvents        = String(localized: "Sun Events")
        static let civilDawn        = String(localized: "Civil Dawn")
        static let sunrise          = String(localized: "Sunrise")
        static let solarNoon        = String(localized: "Solar Noon")
        static let sunset           = String(localized: "Sunset")
        static let civilDusk        = String(localized: "Civil Dusk")
        // Moon events
        static let moonEvents       = String(localized: "Moon Events")
        static let moonPhase        = String(localized: "Phase")
        static let moonrise         = String(localized: "Moonrise")
        static let moonset          = String(localized: "Moonset")
        static let illumination     = String(localized: "Illumination")
        // Proper motion rows
        static let pmRA             = String(localized: "RA  (mas/yr)")
        static let pmDec            = String(localized: "Dec (mas/yr)")
    }

    // MARK: - Weather / Loading states
    struct Weather {
        static let fetching    = String(localized: "Fetching...")
        static let unavailable = String(localized: "Unavailable")
        static let error       = String(localized: "Error")
    }

    // MARK: - Location
    struct Location {
        static let atYourLocation    = String(localized: "At your location")
        static let centreOnLocation  = String(localized: "Centre on your location")
        static let acquiringLocation = String(localized: "Acquiring location...")
        static let tapToEnable       = String(localized: "Tap to enable location")
        static let accessDenied      = String(localized: "Location access denied")
    }

    // MARK: - Constellation detail
    struct ConstellationDetail {
        static let identity     = String(localized: "Identity")
        static let abbreviation = String(localized: "Abbreviation")
        static let fullName     = String(localized: "Full name")
        static let zodiac       = String(localized: "Zodiac")
    }

    // MARK: - Preset names
    struct Preset {
        static let morning       = String(localized: "Morning")
        static let day           = String(localized: "Day")
        static let afternoon     = String(localized: "Afternoon")
        static let night         = String(localized: "Night")
        static let trackSun      = String(localized: "Track Sun")
        static let trackMoon     = String(localized: "Track Moon")
        static let trackStar     = String(localized: "Track Star")
        static let defaultPreset = String(localized: "Default")
    }

    // MARK: - Star list footer
    struct StarList {
        /// Interpolated → extracted as "%lld stars shown"; promote to a
        /// proper plural rule in the catalog (1 star / N stars) when wired.
        static func starsShown(_ count: Int) -> String {
            String(localized: "\(count) stars shown")
        }
    }

    // MARK: - Canonical (NOT localised)
    //
    // These are used as *identity* — switch-case keys, object names,
    // persistence keys, or search-matching tokens — not as display text.
    // Localising them would break logic (a localized value can't match an
    // English-keyed switch or a persisted English name across a language
    // change). Display-name localisation for these (e.g. planet / moon-
    // phase names) belongs in a separate display layer, TBD.

    /// Planet names — `Planet.name` identity, `Palette`/`Artist`
    /// glyph+gradient switch keys, and the `CloudSync` favourites key.
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

    /// Moon-phase names. Resolved by `LunarPhase.name`, which is the only
    /// thing that should map a phase to one of these — there is no
    /// "unknown" fallback any more because the mapping is now total.
    struct MoonPhase {
        static let newMoon        = "New Moon"
        static let waxingCrescent = "Waxing Crescent"
        static let firstQuarter   = "First Quarter"
        static let waxingGibbous  = "Waxing Gibbous"
        static let fullMoon       = "Full Moon"
        static let waningGibbous  = "Waning Gibbous"
        static let lastQuarter    = "Last Quarter"
        static let waningCrescent = "Waning Crescent"
    }

    /// Search-matching keywords (lowercased), not display text.
    struct SearchTokens {
        static let moonToken      = "moon"
        static let moonFullToken  = "moon lunar satellite"
    }

    // MARK: - Format specifiers (not display copy)
    //
    // Format strings for `String(format:)`. Number formatting is a
    // localisation concern, but that's a NumberFormatter job, not a
    // catalog-string one — kept as plain specifiers for now.
    struct Format {
        static let magnFormat = "%.1f mag"
    }

    struct DetailFormat {
        static let distanceLY      = "%.1f ly"
        static let magnitude       = "%.2f"
        static let illuminationPct = "%.1f%%"
        static let raHours         = "%.2fh"
        static let decDeg          = "%+.2f°"
        static let eclipticLonDeg  = "%.3f°"
        static let magLabel        = "mag %.2f"
        static let distanceLabel   = "%.0f ly"
    }

    // MARK: - Fallback (not translatable)
    struct Fallback {
        static let empty   = ""
        static let unknown = "--"
    }
}

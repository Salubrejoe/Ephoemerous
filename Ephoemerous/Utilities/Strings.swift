import Foundation

struct Strings {
    
    // MARK: - App
    struct App {
        static let name                 = "Ephemerous"
        static let bundleID             = "com.licurgen.Ephemerous"
        static let groupContainer       = "group.com.licurgen.Ephemerous"
        static let cloudKitContainer    = "iCloud.com.licurgen.Ephemerous"
    }
    
    
    
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
        static let searchBar   = "Search the sky"
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
    
    // MARK: - Logging
    struct Logging {
        static let debug   = "[DEBUG]"
        static let info    = "[INFO]"
        static let warning = "[WARNING]"
        static let error   = "[ERROR]"
        static let fault   = "[FAULT]"
    }
    
    // MARK: - Symbols
    enum Symbols: String {
        
        case calendar      = "calendar"
        case checkmark     = "checkmark"
        case chevronUpDown = "chevron.up.chevron.down"
        case circle        = "circle"
        case cup           = "cup.and.heat.waves"
        case cupEmpty      = "cup.and.saucer"
        case drop          = "drop.fill"
        case flame         = "flame"
        case location      = "location"
        case locationFill  = "location.fill"
        case plus          = "plus"
        case record        = "smallcircle.filled.circle"
        case reset         = "arrow.counterclockwise"
        case resetClock    = "clock.arrow.circlepath"
        case save          = "square.and.arrow.down"
        case scalemass     = "scalemass"
        case search        = "magnifyingglass"
        case sort          = "line.3.horizontal.decrease.circle"
        case star          = "star"
        case starFill      = "star.fill"
        case stopFill      = "stop.fill"
        case target        = "target"
        case timer         = "timer"
        case trash         = "trash"
        case thumbsup      = "hand.thumbsup"
        case warning       = "exclamationmark.triangle.fill"
        case xmark         = "xmark"
        
        var description: String { self.rawValue }
        
    }
    
    struct Format {
        static let magnFormat         = "%.1f mag"
    }
    
    // MARK: - Fallback
    struct Fallback {
        static let empty                = ""
        static let unknown              = "--"
    }

/*
    // MARK: - Random
    struct Random {
        static func animalFace() -> String {
            let animals = [
                "🐶", "🐱", "🐻", "🐼", "🐨",
                "🐯", "🦊", "🦁", "🐮",
                "🐷", "🐹", "🐰", "🦦",
                "🦄", "🦋", "🐭",
            ]
            return animals.randomElement()!
        }
    }
    
    
    // MARK: - Tabs
    struct Tabs {
        static let timer                = "Timer"
        static let recipes              = "Recipes"
        static let coffees              = "Coffees"
    }
    
    // MARK: - Timer
    struct Timer {
        static let liveActivityStarted      = "☕️ Live Activity started"
        static let heroIdle      = "Free Pour!"
        static let heroReady     = ""
        static func heroFirstDrop(_ drop: String) -> String { "First drop after \(drop)" }
        static let start                = "START"
        static let stop                 = "STOP"
        static let done                 = "DONE"
        static let save                 = "SAVE"
        static let reset                = "RESET"
        static let firstDrop            = "First Drop"
        static let firstDropLabel       = "First drop:"
        static let targetTime           = "Target Time"
        static let shotTime             = "Shot Time"
        static let weightIn             = "Dose In"
        static let weightOut            = "Yield Out"
        static let noRecipe             = "No Recipe"
        static let newRecipe            = "New Recipe"
        static let freePour             = "Free Pour"
        static let helloEmoji           = "👋 Hello!"
        static let shotSummary          = "Shot Summary"
        static let saveShot             = "Save Shot"
        static let weightPlaceholder    = "0.0"
        static let weightFormat         = "%.1f g"
        static let liveActivityTitle    = "Espresso in Progress"
        static let liveActivitySubtitle = "Pouring..."
        static let pouring              = "Pouring..."
        static let liveActivityStopped  = "Done ☺️"
        static let doneEmoji            = "Done ☺️"
    }
*/
    
    

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
        // Sun specific
        static let sunEvents        = "Sun Events"
        static let sunType          = "G-type main-sequence"
        static let sunDistance      = "1.000 AU"
        static let sunMagnitude     = "-26.74"
        static let sunTemperature   = "5,778 K"
        static let sunRadius        = "696,000 km"
        // Sun event rows
        static let civilDawn        = "Civil Dawn"
        static let sunrise          = "Sunrise"
        static let solarNoon        = "Solar Noon"
        static let sunset           = "Sunset"
        static let civilDusk        = "Civil Dusk"
        // Moon specific
        static let moonEvents       = "Moon Events"
        static let moonType         = "Natural satellite"
        static let moonDiameter     = "3,474 km"
        static let moonDistance     = "~384,400 km"
        static let moonPeriod       = "27.3 days"
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
}

import Foundation

// MARK: - Logger
/// Centralised console logger for Ephoemerous.
/// Wraps os.log / print behind a DEBUG guard so release builds stay silent.
/// Usage:  Logger.sun("RA: 12h 00m")
enum Logger {

    enum Category: String {
        case sun            = "Sun"
        case moon           = "Moon"
        case planet         = "Planet"
        case favourites     = "Favourites"
        case starDatabase   = "StarDatabase"
        case location       = "Location"
        case constellationLines = "ConstellationLines"
    }

    private static func log(_ category: Category, _ message: String) {
#if DEBUG
        print("[\(category.rawValue)] \(message)")
#endif
    }

    static func sun(_ message: String)           { log(.sun,           message) }
    static func moon(_ message: String)          { log(.moon,          message) }
    static func planet(_ message: String)        { log(.planet,        message) }
    static func favourites(_ message: String)    { log(.favourites,    message) }
    static func starDatabase(_ message: String)  { log(.starDatabase,  message) }
    static func location(_ message: String)      { log(.location,      message) }
    static func constellationLines(_ message: String) { log(.constellationLines, message) }
}

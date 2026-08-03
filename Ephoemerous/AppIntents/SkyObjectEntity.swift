import AppIntents
import Foundation

// MARK: - SkyObjectEntity
// `SkyObject` as the system sees it — the AppEntity that widgets
// (configuration parameter), Shortcuts and Siri all resolve against.
// The exposed universe: the Sun, the Moon, each planet, and every
// favourite (stars + constellations ride in through the favourites).
//
// IDENTITY: ids must survive relaunch AND cross processes (a widget
// stores the id and resolves it cold), so they are built on the same
// canonical names the iCloud favourites keys use — NOT `SkyObject.id`,
// whose star arm embeds a per-launch UUID:
//
//   sun · moon · planet_Mars · star_Sirius · constellation_orion
//
// The entity itself is a dumb snapshot (id + display strings); the live
// model object is re-resolved from the id via `skyObject` at use time.
struct SkyObjectEntity: AppEntity {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Sky Object"
    static let defaultQuery = SkyObjectQuery()

    let id:         String
    let name:       String
    let subtitle:   String
    let symbolName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title:    "\(name)",
                              subtitle: "\(subtitle)",
                              image:    .init(systemName: symbolName))
    }

    // MARK: SkyObject → entity

    init(_ obj: SkyObject) {
        switch obj {
        case .star(let s):
            id         = "star_\(s.name)"
            name       = s.displayName
            subtitle   = s.constellation.localizedName
            symbolName = "star.fill"
        case .sun:
            id         = "sun"
            name       = obj.displayName
            subtitle   = String(localized: "Star")
            symbolName = "sun.max.fill"
        case .moon:
            id         = "moon"
            name       = obj.displayName
            subtitle   = String(localized: "Moon")
            symbolName = "moon.fill"
        case .planet(let p):
            id         = "planet_\(p.name)"
            name       = p.displayName
            subtitle   = String(localized: "Planet")
            symbolName = "circle.fill"
        case .constellation(let c):
            id         = "constellation_\(c.rawValue)"
            name       = c.localizedName
            subtitle   = String(localized: "Constellation")
            symbolName = "sparkles"
        }
    }

    // MARK: id → entity / model

    /// Rebuild from a stored id (widget configurations, Shortcuts
    /// donations). Fails only when the id names a star that no longer
    /// resolves in the database.
    @MainActor
    init?(id: String) {
        guard let obj = Self.skyObject(for: id) else { return nil }
        self.init(obj)
    }

    /// The live model object this entity stands for — resolved fresh so
    /// stars come back as real `Star`s, not stale snapshots.
    @MainActor
    var skyObject: SkyObject? { Self.skyObject(for: id) }

    @MainActor
    private static func skyObject(for id: String) -> SkyObject? {
        switch id {
        case "sun":  return .sun
        case "moon": return .moon
        default:
            if id.hasPrefix("planet_") {
                let name = String(id.dropFirst("planet_".count))
                return Planet.all.first { $0.name == name }
                                  .map(SkyObject.planet)
            }
            if id.hasPrefix("constellation_") {
                let raw = String(id.dropFirst("constellation_".count))
                return Constellation(rawValue: raw)
                                  .map(SkyObject.constellation)
            }
            if id.hasPrefix("star_") {
                let name = String(id.dropFirst("star_".count))
                return StarDatabase.shared.workableStars
                                  .first { $0.name == name }
                                  .map(SkyObject.star)
            }
            return nil
        }
    }
}

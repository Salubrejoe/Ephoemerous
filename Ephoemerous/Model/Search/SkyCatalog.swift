import Foundation

// MARK: - BrowseChip
// The search sheet's browse categories — a row of chips under the field,
// so finding something never requires typing.
enum BrowseChip: String, CaseIterable, Identifiable {
    case favorites, stars, constellations, planets, spacecraft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites:      return String(localized: "Pins")
        case .stars:          return String(localized: "Stars")
        case .constellations: return String(localized: "Constellations")
        case .planets:        return String(localized: "Planets")
        case .spacecraft:     return String(localized: "Spacecraft")
        }
    }
}

// MARK: - SkyCatalog
// What each chip lists, split into what's above the horizon right now and
// what isn't — the question you're actually asking when you open an
// astronomy app. Built for one moment and one place, so the sheet only
// lays it out.
//
// Ordering inside each half:
//   • Favorites       — A to Z; it's your list, you know it by name.
//   • Constellations  — up: highest first (easiest to find); down: A to Z.
//   • everything else — brightest first.
struct SkyCatalog {

    let date:       Date
    let observer:   SatelliteSky.Observer
    /// The stored favourites, unfiltered.
    let favourites: [SkyObject]

    struct Entry: Identifiable {
        let object:   SkyObject
        /// Radians above the horizon; nil when it can't be placed.
        let altitude: Double?
        var id: String { object.id }
        var isUp: Bool { (altitude ?? -1) > 0 }
        /// Whole degrees above the horizon, for the row's trailing figure.
        var altitudeDegrees: Int? {
            guard let altitude, altitude > 0 else { return nil }
            return Int((altitude * 180 / .pi).rounded())
        }
    }

    struct Listing {
        let upNow: [Entry]
        let below: [Entry]
        var isEmpty: Bool { upNow.isEmpty && below.isEmpty }
    }

    func listing(for chip: BrowseChip) -> Listing {
        let entries = objects(for: chip).map { Entry(object: $0, altitude: $0.altitude(at: date, from: observer)) }
        let up      = entries.filter(\.isUp)
        let down    = entries.filter { !$0.isUp }
        switch chip {
        case .favorites:
            return Listing(upNow: up.sorted(by: alphabetically), below: down.sorted(by: alphabetically))
        case .constellations:
            return Listing(upNow: up.sorted { ($0.altitude ?? 0) > ($1.altitude ?? 0) },
                           below: down.sorted(by: alphabetically))
        case .stars, .planets, .spacecraft:
            return Listing(upNow: up.sorted(by: brightestFirst), below: down.sorted(by: brightestFirst))
        }
    }

    /// The favourites worth showing: stars and constellations, the two
    /// species the heart exists for. Anything else in the stored set is
    /// stale and stays hidden.
    var favoriteObjects: [SkyObject] {
        favourites.filter {
            switch $0 {
            case .star, .constellation: return true
            default:                    return false
            }
        }
    }

    /// The chip to open on: Favorites when there are some, otherwise Stars,
    /// so the sheet never opens on an empty, unexplained list.
    var defaultChip: BrowseChip { favoriteObjects.isEmpty ? .stars : .favorites }

    /// "Next pass Fri 2, 21:14" for a spacecraft with one coming; otherwise
    /// the object's portrait line.
    func subtitle(for object: SkyObject) -> String {
        if case .spacecraft(let craft) = object,
           let pass = SpacecraftTracker.shared.nextVisiblePass(of: craft, after: date) {
            return String(localized: "Next pass \(SpacecraftFacts.whenText(pass))")
        }
        return object.portrait
    }

    // MARK: Sources

    private func objects(for chip: BrowseChip) -> [SkyObject] {
        switch chip {
        case .favorites:
            return favoriteObjects
        case .stars:
            // The named stars: a few hundred with proper names. The
            // Greek-letter-only ones (a thousand more) are for typing.
            return StarDatabase.shared.listableStars
                .filter { $0.properName != nil }
                .map { .star($0) }
        case .constellations:
            return Constellation.allCases.filter { $0 != .none }.map { .constellation($0) }
        case .planets:
            return [.sun, .moon] + Planet.all.map { .planet($0) }
        case .spacecraft:
            return Spacecraft.allCases.map { .spacecraft($0) }
        }
    }

    // MARK: Ordering

    private func alphabetically(_ a: Entry, _ b: Entry) -> Bool {
        a.object.displayName.localizedStandardCompare(b.object.displayName) == .orderedAscending
    }

    private func brightestFirst(_ a: Entry, _ b: Entry) -> Bool {
        a.object.orderingMagnitude < b.object.orderingMagnitude
    }
}

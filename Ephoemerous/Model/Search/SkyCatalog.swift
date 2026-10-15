import Foundation
import simd

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

// MARK: - BrowseSort
// One order for every chip, picked from the button at the end of the chip
// row. Up now is the default — the question you're actually asking when you
// open an astronomy app; the others flatten the list into one run.
enum BrowseSort: String, CaseIterable, Identifiable {
    case upNow, magnitude, distance, season

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upNow:     return String(localized: "Up now")
        case .magnitude: return String(localized: "Magnitude")
        case .distance:  return String(localized: "Distance")
        case .season:    return String(localized: "Season")
        }
    }

    var systemImage: String {
        switch self {
        case .upNow:     return "arrow.up.and.line.horizontal.and.arrow.down"
        case .magnitude: return "sparkle"
        case .distance:  return "ruler"
        case .season:    return "calendar"
        }
    }
}

// MARK: - SkyCatalog
// What each chip lists, in the chosen order. Built for one moment and one
// place, so the sheet only lays it out.
//
// Up now splits the list into what's above the horizon and what isn't.
// Ordering inside each half:
//   • Favorites       — A to Z; it's your list, you know it by name.
//   • Constellations  — up: highest first (easiest to find); down: A to Z.
//   • everything else — brightest first.
//
// The other orders are one flat run, and each row's trailing figure says
// what it was sorted by:
//   • Magnitude — brightest first; a constellation by its brightest star.
//   • Distance  — nearest first; a constellation by its brightest star.
//                 Stars we hold no distance for go last.
//   • Season    — best seen soonest. Stars and constellations: the night
//                 they're highest at midnight. The Moon: the next full Moon.
//                 Planets: opposition, or greatest elongation for Mercury
//                 and Venus. Spacecraft: the next visible pass. Anything
//                 whose best was within the last few weeks is still in
//                 season, and counts by how long ago.
struct SkyCatalog {

    let date:       Date
    let observer:   SatelliteSky.Observer
    /// The stored favourites, unfiltered.
    let favourites: [SkyObject]

    struct Entry: Identifiable {
        let object:   SkyObject
        /// Radians above the horizon; nil when it can't be placed.
        let altitude: Double?
        /// The row's trailing figure under a flat sort — what it was
        /// sorted by. Nil under Up now, where the altitude speaks.
        var figure:   String? = nil
        var id: String { object.id }
        var isUp: Bool { (altitude ?? -1) > 0 }
        /// Whole degrees above the horizon, for the row's trailing figure.
        var altitudeDegrees: Int? {
            guard let altitude, altitude > 0 else { return nil }
            return Int((altitude * 180 / .pi).rounded())
        }
    }

    struct Section: Identifiable {
        let title:   String
        let entries: [Entry]
        var id: String { title }
    }

    struct Listing {
        let sections: [Section]
        var isEmpty: Bool { sections.allSatisfy(\.entries.isEmpty) }
    }

    func listing(for chip: BrowseChip, sortedBy sort: BrowseSort = .upNow) -> Listing {
        let objects = objects(for: chip)
        switch sort {
        case .upNow:     return upNowListing(objects, chip: chip)
        case .magnitude: return flat(objects, title: String(localized: "Brightest first"),
                                     key: magnitudeKey, figure: magnitudeFigure)
        case .distance:  return flat(objects, title: String(localized: "Nearest first"),
                                     key: distanceKey, figure: distanceFigure)
        case .season:    return seasonListing(objects)
        }
    }

    private func upNowListing(_ objects: [SkyObject], chip: BrowseChip) -> Listing {
        let entries = objects.map { Entry(object: $0, altitude: $0.altitude(at: date, from: observer)) }
        let up      = entries.filter(\.isUp)
        let down    = entries.filter { !$0.isUp }
        let halves: ([Entry], [Entry])
        switch chip {
        case .favorites:
            halves = (up.sorted(by: alphabetically), down.sorted(by: alphabetically))
        case .constellations:
            halves = (up.sorted { ($0.altitude ?? 0) > ($1.altitude ?? 0) }, down.sorted(by: alphabetically))
        case .stars, .planets, .spacecraft:
            halves = (up.sorted(by: brightestFirst), down.sorted(by: brightestFirst))
        }
        return Listing(sections: [Section(title: String(localized: "Up now"),           entries: halves.0),
                                  Section(title: String(localized: "Below the horizon"), entries: halves.1)]
                                  .filter { !$0.entries.isEmpty })
    }

    /// One run, smallest key first; objects with no key go last, A to Z.
    private func flat(_ objects: [SkyObject], title: String,
                      key: (SkyObject) -> Double?, figure: (SkyObject) -> String?) -> Listing {
        let keyed = objects.map { (obj: $0, key: key($0)) }
        let known = keyed.filter { $0.key != nil }.sorted { $0.key! < $1.key! }
        let rest  = keyed.filter { $0.key == nil }
            .sorted { $0.obj.displayName.localizedStandardCompare($1.obj.displayName) == .orderedAscending }
        let entries = (known + rest).map {
            Entry(object: $0.obj, altitude: $0.obj.altitude(at: date, from: observer), figure: figure($0.obj))
        }
        return Listing(sections: entries.isEmpty ? [] : [Section(title: title, entries: entries)])
    }

    // MARK: Magnitude

    private func magnitudeKey(_ obj: SkyObject) -> Double? {
        if case .constellation(let c) = obj { return Self.brightestStar[c]?.magnitude }
        return obj.orderingMagnitude
    }

    private func magnitudeFigure(_ obj: SkyObject) -> String? {
        // Rounded first, so Rigil Kentaurus's −0.01 reads 0.0, not −0.0.
        magnitudeKey(obj).map { (($0 * 10).rounded() / 10 + 0).formatted(.number.precision(.fractionLength(1))) }
    }

    // MARK: Distance

    /// Kilometres, so every kind sorts on one scale.
    private func distanceKey(_ obj: SkyObject) -> Double? {
        let auKm = 149_597_870.7, lyKm = 9_460_730_472_580.8
        switch obj {
        case .star(let s):          return s.distanceLY.map { $0 * lyKm }
        case .constellation(let c): return Self.brightestStar[c]?.distanceLY.map { $0 * lyKm }
        case .sun:                  return PlanetPosition.sunDistanceAU(date: date) * auKm
        case .moon:                 return MoonPosition.distanceKm(for: date)
        case .planet(let p):        return PlanetPosition.distanceAU(p, date: date).map { $0 * auKm }
        case .spacecraft(let c):    return SpacecraftTracker.shared.rangeKm(of: c, at: date, from: observer)
        case .deepSky(let d):       return d.distance.map { $0 * lyKm }
        }
    }

    /// The Look ring's own label where it has one; a constellation by its
    /// brightest star, a spacecraft by its range.
    private func distanceFigure(_ obj: SkyObject) -> String? {
        switch obj {
        case .constellation(let c):
            return Self.brightestStar[c].flatMap { SkyObject.star($0).distanceLabel(at: date) }
        case .spacecraft(let c):
            guard let km = SpacecraftTracker.shared.rangeKm(of: c, at: date, from: observer) else { return nil }
            return String(localized: "\(Int((km / 10).rounded() * 10), format: .number) km")
        default:
            return obj.distanceLabel(at: date)
        }
    }

    // MARK: Season

    /// How far a best night may lie behind us and still count as in season.
    private static let seasonGrace: Double = 45

    private func seasonListing(_ objects: [SkyObject]) -> Listing {
        let days: [String: Double] = Dictionary(uniqueKeysWithValues: objects.compactMap { obj in
            seasonDays(obj).map { (obj.id, $0) }
        })
        return flat(objects, title: String(localized: "Best seen soonest"),
                    key: { days[$0.id].map(abs) },
                    figure: { days[$0.id].map(seasonFigure) })
    }

    /// Days from now to the object's best night — negative when it was
    /// lately. Nil when there's no such night to name.
    private func seasonDays(_ obj: SkyObject) -> Double? {
        switch obj {
        case .star, .constellation, .deepSky:
            guard let v = obj.equatorialDirection(at: date, from: observer) else { return nil }
            let sun   = SkyObject.sun.equatorialDirection(at: date, from: observer) ?? v
            // Highest at midnight when it stands opposite the Sun; the Sun
            // gains a full turn of right ascension a year.
            let turn  = 2 * Double.pi
            let gap   = (atan2(v.y, v.x) + .pi - atan2(sun.y, sun.x)).truncatingRemainder(dividingBy: turn)
            let days  = (gap < 0 ? gap + turn : gap) / turn * 365.25
            return days > 365.25 - Self.seasonGrace ? days - 365.25 : days
        case .sun:
            return 0                     // every day is the Sun's
        case .moon, .planet:
            return SolarSeason.days(to: obj, from: date)
        case .spacecraft(let c):
            guard let pass = SpacecraftTracker.shared.nextVisiblePass(of: c, after: date) else { return nil }
            return pass.rise.date.timeIntervalSince(date) / 86_400
        }
    }

    private func seasonFigure(_ days: Double) -> String {
        if abs(days) < 1 { return String(localized: "Tonight") }
        return date.addingTimeInterval(days * 86_400)
            .formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: Brightest star per constellation

    /// A constellation measured by its brightest star — built once.
    private static let brightestStar: [Constellation: Star] = {
        var best: [Constellation: Star] = [:]
        for star in StarDatabase.shared.workableStars where star.constellation != .none {
            if let b = best[star.constellation], b.magnitude <= star.magnitude { continue }
            best[star.constellation] = star
        }
        return best
    }()

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

// MARK: - SolarSeason
// The Moon's and the planets' best nights, found by walking their
// elongation from the Sun: the nearest peak is the full Moon, an outer
// planet's opposition, or Mercury's and Venus's greatest elongation. Walked
// once a day per body and kept — the walk is a few hundred ephemerides.
@MainActor
private enum SolarSeason {
    private static var cache: [String: Double] = [:]
    private static var cacheDay: Date?

    static func days(to obj: SkyObject, from date: Date) -> Double? {
        let day = Calendar.current.startOfDay(for: date)
        if cacheDay != day { cache = [:]; cacheDay = day }
        if let hit = cache[obj.id] { return hit - date.timeIntervalSince(day) / 86_400 }
        guard let found = walk(obj, from: day) else { return nil }
        cache[obj.id] = found
        return found - date.timeIntervalSince(day) / 86_400
    }

    /// Days from `day` to the nearest elongation peak, looking back as far
    /// as the season grace and forward a little over Mars's synodic period.
    private static func walk(_ obj: SkyObject, from day: Date) -> Double? {
        let isMoon = obj == .moon
        let step   = isMoon ? 0.5 : 2.0
        let back   = isMoon ? 3.0 : 45.0
        let ahead  = isMoon ? 32.0 : 800.0
        let observer = SatelliteSky.Observer(latitude: 0, longitude: 0)
        var samples: [(t: Double, e: Double)] = []
        var t = -back
        while t <= ahead {
            let when = day.addingTimeInterval(t * 86_400)
            guard let v   = obj.equatorialDirection(at: when, from: observer),
                  let sun = SkyObject.sun.equatorialDirection(at: when, from: observer) else { return nil }
            samples.append((t, acos(max(-1, min(1, simd_dot(simd_normalize(v), simd_normalize(sun)))))))
            t += step
        }
        let peaks = samples.indices.dropFirst().dropLast().filter {
            samples[$0].e >= samples[$0 - 1].e && samples[$0].e > samples[$0 + 1].e
        }.map { samples[$0].t }
        return peaks.min { abs($0) < abs($1) }
    }
}

import Foundation

// MARK: - SkyStatus
// Where an object stands against your horizon at the observation moment,
// and what it does next — the detail header's one subtitle, read like Maps'
// "Open · Closes 22:00":
//
//   ● Up · 41° W · sets 14:20          ○ Below the horizon · rises 19:05
//   ● Up · 51° N · never sets          ○ Never rises here
//   ○ Below the horizon · next pass 21:14   (low-orbit spacecraft)
//
// Rise and set come from sampling the object's altitude across the next
// day and bisecting each crossing to the minute — one function for stars,
// the Moon, planets and Webb alike. A low-orbit craft crosses the sky in
// minutes and laps the Earth every ninety, so for those the next VISIBLE
// pass is the useful "next".
struct SkyStatus: Equatable {

    enum Next: Equatable {
        case sets(Date), rises(Date), pass(Date)
        case neverSets, neverRises
        case unknown
    }

    let isUp:     Bool
    /// Whole degrees above the horizon (when up).
    let altitude: Int
    /// 16-point compass direction ("WNW").
    let compass:  String
    let next:     Next

    /// How far ahead rise/set are looked for, and how finely.
    private static let window:  TimeInterval = 24 * 3_600
    private static let step:    TimeInterval = 10 * 60

    /// nil when the object can't be placed at `date` (a spacecraft with no
    /// orbit data for it).
    init?(object: SkyObject, date: Date, observer: SatelliteSky.Observer) {
        guard let direction = object.equatorialDirection(at: date, from: observer) else { return nil }
        let here  = SatelliteSky.horizontal(of: direction, from: observer, date: date)
        isUp      = here.altitude > 0
        altitude  = Int((here.altitude * 180 / .pi).rounded())
        compass   = SpacecraftFacts.compassPoint(here.azimuth)

        if case .spacecraft(let craft) = object, craft.isInEarthOrbit {
            next = SpacecraftTracker.shared.nextVisiblePass(of: craft, after: date)
                .map { .pass(($0.visibleStart ?? $0.rise).date) } ?? .unknown
            return
        }
        next = Self.nextCrossing(of: object, from: date, observer: observer, startsUp: here.altitude > 0)
    }

    /// The first horizon crossing in the window, or "never" when the
    /// altitude keeps one sign the whole day.
    private static func nextCrossing(of object: SkyObject, from date: Date,
                                     observer: SatelliteSky.Observer, startsUp: Bool) -> Next {
        func altitude(_ t: Date) -> Double? { object.altitude(at: t, from: observer) }
        var previous = date
        var t        = date.addingTimeInterval(step)
        while t.timeIntervalSince(date) <= window {
            guard let a = altitude(t) else { return .unknown }
            if (a > 0) != startsUp {
                let crossing = bisect(between: previous, and: t, startsUp: startsUp, altitude: altitude)
                return startsUp ? .sets(crossing) : .rises(crossing)
            }
            previous = t
            t        = t.addingTimeInterval(step)
        }
        return startsUp ? .neverSets : .neverRises
    }

    /// Narrow a crossing to within a minute.
    private static func bisect(between a: Date, and b: Date, startsUp: Bool,
                               altitude: (Date) -> Double?) -> Date {
        var lo = a, hi = b
        while hi.timeIntervalSince(lo) > 60 {
            let mid = lo.addingTimeInterval(hi.timeIntervalSince(lo) / 2)
            guard let alt = altitude(mid) else { return mid }
            if (alt > 0) == startsUp { lo = mid } else { hi = mid }
        }
        return hi
    }

    // MARK: Cache

    /// The status for this object, minute and place — computed once. The
    /// header re-renders as the clock ticks; a rise/set search per frame
    /// would be ~150 position evaluations for nothing new.
    @MainActor
    static func cached(object: SkyObject, date: Date, observer: SatelliteSky.Observer) -> SkyStatus? {
        let key = "\(object.id)|\(Int(date.timeIntervalSince1970 / 60))|"
                + "\(Int(observer.latitude * 1e4))|\(Int(observer.longitude * 1e4))"
        if let hit = cache[key] { return hit }
        let status = SkyStatus(object: object, date: date, observer: observer)
        if cache.count > 64 { cache.removeAll() }
        cache[key] = status
        return status
    }

    @MainActor private static var cache: [String: SkyStatus?] = [:]

    // MARK: Wording

    /// "Up · 41° W" / "Below the horizon" / "Never rises here".
    var headline: String {
        if next == .neverRises { return String(localized: "Never rises here") }
        return isUp ? String(localized: "Up · \(altitude)° \(compass)")
                    : String(localized: "Below the horizon")
    }

    /// "sets 14:20" / "rises 19:05" / "never sets" / "next pass 21:14".
    var detail: String? {
        switch next {
        case .sets(let d):  return String(localized: "sets \(Self.time(d))")
        case .rises(let d): return String(localized: "rises \(Self.time(d))")
        case .pass(let d):  return String(localized: "next pass \(Self.time(d))")
        case .neverSets:    return String(localized: "never sets")
        case .neverRises, .unknown: return nil
        }
    }

    private static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

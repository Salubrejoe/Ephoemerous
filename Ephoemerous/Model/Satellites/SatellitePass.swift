import Foundation

// MARK: - SatellitePass
// One trip of a spacecraft across the observer's sky, horizon to horizon,
// plus the part of it you can actually see: the craft sunlit, above 10°,
// against a sky darker than civil twilight. Most passes have no such part —
// the daytime ones, and the ones spent in Earth's shadow.
nonisolated struct SatellitePass: Hashable, Sendable, Identifiable {

    struct Point: Hashable, Sendable {
        let date:     Date
        let azimuth:  Double   // rad
        let altitude: Double   // rad
    }

    let rise:     Point
    let peak:     Point
    let set:      Point
    /// First → last visible instant, or nil when the whole pass is lost to
    /// daylight or shadow.
    let visibleStart: Point?
    let visibleEnd:   Point?
    /// Brightest estimated magnitude while visible.
    let magnitude:    Double?

    var id:        Date { rise.date }
    var isVisible: Bool { visibleStart != nil }
}

// MARK: - Prediction

nonisolated enum SatellitePassPredictor {

    /// ▼ TWEAK the visibility rules here ▼
    static let minimumVisibleAltitude: Double = 10 * .pi / 180
    static let darkSkySunAltitude:     Double = -6 * .pi / 180
    private static let coarseStep:     TimeInterval = 20
    private static let fineStep:       TimeInterval = 5

    /// Every pass that rises within `[start, start + span)`. A pass already
    /// in progress at `start` is reported from `start`.
    static func passes(of orbit: SGP4,
                       standardMagnitude: Double,
                       from observer: SatelliteSky.Observer,
                       start: Date,
                       span: TimeInterval) -> [SatellitePass] {
        var passes: [SatellitePass] = []
        var t          = start
        var wasUp      = altitude(orbit, observer, t).map { $0 > 0 } ?? false
        var riseDate   = wasUp ? start : nil
        let end        = start.addingTimeInterval(span)

        while t < end || riseDate != nil {
            let next = t.addingTimeInterval(coarseStep)
            guard let alt = altitude(orbit, observer, next) else { break }
            let isUp = alt > 0
            if isUp, !wasUp {
                riseDate = horizonCrossing(orbit, observer, from: t, to: next)
            } else if !isUp, wasUp, let rise = riseDate {
                let set = horizonCrossing(orbit, observer, from: t, to: next)
                if let pass = describe(orbit, standardMagnitude, observer, rise: rise, set: set) {
                    passes.append(pass)
                }
                riseDate = nil
            }
            wasUp = isUp
            t     = next
            if t > end.addingTimeInterval(3_600) { break }   // runaway guard
        }
        return passes
    }

    // MARK: Pieces

    private static func altitude(_ orbit: SGP4, _ observer: SatelliteSky.Observer, _ date: Date) -> Double? {
        guard let state = try? orbit.state(at: date) else { return nil }
        return SatelliteSky.look(at: state.position, from: observer, date: date).altitude
    }

    /// Bisects the horizon crossing between two samples to about a second.
    private static func horizonCrossing(_ orbit: SGP4, _ observer: SatelliteSky.Observer,
                                        from a: Date, to b: Date) -> Date {
        var lo      = a
        var hi      = b
        let loIsUp  = (altitude(orbit, observer, a) ?? 0) > 0
        while hi.timeIntervalSince(lo) > 1 {
            let mid = lo.addingTimeInterval(hi.timeIntervalSince(lo) / 2)
            if ((altitude(orbit, observer, mid) ?? 0) > 0) == loIsUp { lo = mid } else { hi = mid }
        }
        return hi
    }

    /// Walks the pass at the fine step for its peak and visible stretch.
    private static func describe(_ orbit: SGP4, _ standardMagnitude: Double,
                                 _ observer: SatelliteSky.Observer,
                                 rise: Date, set: Date) -> SatellitePass? {
        var peak:         SatellitePass.Point?
        var visibleStart: SatellitePass.Point?
        var visibleEnd:   SatellitePass.Point?
        var brightest:    Double?
        var riseAz        = 0.0
        var setAz         = 0.0

        var t = rise
        while t <= set {
            guard let state = try? orbit.state(at: t) else { return nil }
            let look  = SatelliteSky.look(at: state.position, from: observer, date: t)
            let point = SatellitePass.Point(date: t, azimuth: look.azimuth, altitude: look.altitude)
            if t == rise { riseAz = look.azimuth }
            setAz = look.azimuth
            if look.altitude > (peak?.altitude ?? -.infinity) { peak = point }

            let sun = SatelliteSky.sunDirection(t)
            if look.altitude >= minimumVisibleAltitude,
               SatelliteSky.isSunlit(state.position, sun: sun),
               SatelliteSky.altitude(of: sun, from: observer, date: t) <= darkSkySunAltitude {
                if visibleStart == nil { visibleStart = point }
                visibleEnd = point
                let mag    = SatelliteSky.magnitude(standard: standardMagnitude, look: look, sun: sun)
                brightest  = min(brightest ?? mag, mag)
            }
            t = t.addingTimeInterval(fineStep)
        }

        guard let peak else { return nil }
        return SatellitePass(rise:         .init(date: rise, azimuth: riseAz, altitude: 0),
                             peak:         peak,
                             set:          .init(date: set,  azimuth: setAz,  altitude: 0),
                             visibleStart: visibleStart,
                             visibleEnd:   visibleEnd,
                             magnitude:    brightest)
    }
}

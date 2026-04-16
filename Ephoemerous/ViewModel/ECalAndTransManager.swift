import Foundation
import CoreLocation

enum ECalAndTransManager {
    typealias Radians = Double

    static let j2000: Date = {
        var c = DateComponents()
        c.year = 2000; c.month = 1; c.day = 1
        c.hour = 12; c.minute = 0; c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    static func julianDate(from date: Date) -> Double {
        date.timeIntervalSince1970 / 86400.0 + 2_440_587.5
    }

    static func julianCenturies(from date: Date) -> Double {
        (julianDate(from: date) - 2_451_545.0) / 36_525.0
    }

    static func gmst(for date: Date) -> Radians {
        let T = julianCenturies(from: date)
        let gmst0 = 24110.54841
                  + 8640184.812866 * T
                  + 0.093104       * T * T
                  - 6.2e-6         * T * T * T
        let utc = TimeZone(identifier: "UTC")!
        let comps = Calendar(identifier: .gregorian).dateComponents(in: utc, from: date)
        let secondsSinceMidnight = Double((comps.hour ?? 0) * 3600
                                       + (comps.minute ?? 0) * 60
                                       + (comps.second ?? 0))
        let totalSeconds = gmst0 + secondsSinceMidnight * 1.00273790935
        let radians = (totalSeconds / 86400.0) * 2.0 * Double.pi
        return radians.truncatingRemainder(dividingBy: 2.0 * Radians.pi)
    }

    static func lst(for date: Date, longitude: CLLocationDegrees) -> Radians {
        let g = gmst(for: date)
        let lonRad = longitude * Double.pi / 180.0
        return (g + lonRad).truncatingRemainder(dividingBy: 2.0 * Radians.pi)
    }

    static func precess(ra: Radians, dec: Radians, to date: Date) -> (ra: Radians, dec: Radians) {
        let T = julianCenturies(from: date)
        guard abs(T) > 1e-6 else { return (ra, dec) }
        let k = Double.pi / (180.0 * 3600.0)
        let zeta  = ((2306.2181 + 1.39656*T - 0.000139*T*T)*T + (0.30188 - 0.000344*T)*T*T + 0.017998*T*T*T) * k
        let z     = ((2306.2181 + 1.39656*T - 0.000139*T*T)*T + (1.09468 + 0.000066*T)*T*T + 0.018203*T*T*T) * k
        let theta = ((2004.3109 - 0.85330*T - 0.000217*T*T)*T - (0.42665 + 0.000217*T)*T*T - 0.041775*T*T*T) * k
        let A = cos(dec) * sin(ra + zeta)
        let B = cos(theta) * cos(dec) * cos(ra + zeta) - sin(theta) * sin(dec)
        let C = sin(theta) * cos(dec) * cos(ra + zeta) + cos(theta) * sin(dec)
        let newRA  = (atan2(A, B) + z).truncatingRemainder(dividingBy: 2.0 * Radians.pi)
        let newDec = asin(max(-1, min(1, C)))
        return (newRA, newDec)
    }

    static func equatorialVector(ra: Radians, dec: Radians) -> SIMD3<Double> {
        SIMD3(cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec))
    }

    static func siderealOffset(for date: Date) -> Double {
        gmst(for: date)
    }
}

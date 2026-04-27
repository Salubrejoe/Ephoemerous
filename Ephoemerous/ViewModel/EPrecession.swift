import SwiftUI
import CoreLocation

enum EPrecession {
    typealias Seconds = Double

    static let j2000: Date = {
        var c = DateComponents()
        c.year = 2000; c.month = 1; c.day = 1
        c.hour = 12; c.minute = 0; c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    static func julianDate(from date: Date) -> Seconds {
        date.timeIntervalSince1970 / AstroConstants.secondsPerDay + AstroConstants.julianUnixEpoch
    }

    static func julianCenturies(from date: Date) -> Seconds {
        (julianDate(from: date) - AstroConstants.julianJ2000) / AstroConstants.julianDaysPerCentury
    }

    static func gmst(for date: Date) -> Angle {
        let T = julianCenturies(from: date)
        let gmst0 = AstroConstants.gmst_c0
                  + AstroConstants.gmst_c1 * T
                  + AstroConstants.gmst_c2 * T * T
                  + AstroConstants.gmst_c3 * T * T * T
        let utc = TimeZone(identifier: "UTC")!
        let comps = Calendar(identifier: .gregorian).dateComponents(in: utc, from: date)
        let secondsSinceMidnight = Double((comps.hour   ?? 0) * 3600
                                       + (comps.minute ?? 0) * 60
                                       + (comps.second ?? 0))
        let totalSeconds = gmst0 + secondsSinceMidnight * AstroConstants.siderealRatio
        let radians = (totalSeconds / AstroConstants.secondsPerDay) * 2.0 * Double.pi
        return Angle(radians: radians)
    }

    static func lst(for date: Date, longitude: Angle) -> Angle {
        gmst(for: date) + longitude
    }

    static func precess(ra: Angle, dec: Angle, to date: Date) -> (ra: Angle, dec: Angle) {
        let T = julianCenturies(from: date)
        guard abs(T) > 1e-6 else { return (ra, dec) }
        let k = Double.pi / (180.0 * 3600.0) // arc-seconds → radians

        let c0 = AstroConstants.prec_zeta_c0, c1 = AstroConstants.prec_zeta_c1
        let c2 = AstroConstants.prec_zeta_c2, c3 = AstroConstants.prec_zeta_c3
        let c4 = AstroConstants.prec_zeta_c4, c5 = AstroConstants.prec_zeta_c5

        let zeta  = ((c0 + c1*T + c2*T*T)*T + (c3 + c4*T)*T*T + c5*T*T*T) * k
        let z     = ((c0 + c1*T + c2*T*T)*T
                  + (AstroConstants.prec_z_c3 + AstroConstants.prec_z_c4*T)*T*T
                  +  AstroConstants.prec_z_c5*T*T*T) * k

        let t0 = AstroConstants.prec_theta_c0, t1 = AstroConstants.prec_theta_c1
        let t2 = AstroConstants.prec_theta_c2, t3 = AstroConstants.prec_theta_c3
        let t5 = AstroConstants.prec_theta_c5
        let theta = ((t0 + t1*T + t2*T*T)*T - (t3 + t2*T)*T*T - t5*T*T*T) * k

        let A = cos(dec.radians) * sin(ra.radians + zeta)
        let B = cos(theta) * cos(dec.radians) * cos(ra.radians + zeta) - sin(theta) * sin(dec.radians)
        let C = sin(theta) * cos(dec.radians) * cos(ra.radians + zeta) + cos(theta) * sin(dec.radians)
        let newRA  = (atan2(A, B) + z).truncatingRemainder(dividingBy: 2.0 * Double.pi)
        let newDec = asin(max(-1, min(1, C)))
        return (.init(radians: newRA), .init(radians: newDec))
    }

    static func equatorialVector(ra: Angle, dec: Angle) -> SIMD3<Double> {
        SIMD3(
            cos(dec.radians) * cos(ra.radians),
            cos(dec.radians) * sin(ra.radians),
            sin(dec.radians)
        )
    }

    static func gmstSiderealOffset(for date: Date) -> Angle {
        gmst(for: date)
    }

    static func eclipticVector(atStep t: Double, siderealOffset: Angle) -> SIMD3<Double> {
        let λ = t * 2 * .pi
        let β = 0.0
        let θ = siderealOffset.radians
        let ε = AstroConstants.obliquity.radians
        let cb = cos(β), sb = sin(β)
        let cl = cos(λ), sl = sin(λ)
        let xe = cb * cl
        let ye = cb * sl
        let ze = sb
        let yq = ye * cos(ε) - ze * sin(ε)
        let zq = ye * sin(ε) + ze * cos(ε)
        let xq = xe
        return SIMD3(
            xq * cos(θ) - yq * sin(θ),
            xq * sin(θ) + yq * cos(θ),
            zq
        )
    }
}

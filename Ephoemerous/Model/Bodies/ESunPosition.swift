import Foundation
import LoreKit
import SwiftUI

enum ESunPosition {

    // MARK: - Per-frame cache
    //
    // SunLayer calls `eclipticLongitude(for:)` every draw. During pan
    // and zoom the date doesn't change, so we recompute the same
    // Meeus-low-precision series 119 times per second for nothing.
    // Single-entry cache by exact `Date`: hit on pan/zoom (effectively
    // always), miss on time scrub (correct — the user wants the sky
    // to update). Main-thread-only by canvas contract.
    private struct LongitudeCache {
        let date:   Date
        let lambda: Angle
    }
    nonisolated(unsafe) private static var longitudeCache: LongitudeCache?

    /// Apparent ecliptic longitude of the Sun (Meeus S25, low-precision).
    static func eclipticLongitude(for date: Date) -> Angle {
        if let c = longitudeCache, c.date == date { return c.lambda }

        let T = EPrecession.julianCenturies(from: date)
        let AC = AstroConstants.self

        let L0 = (AC.sun_L0_base.degrees
                + AC.sun_L0_c1 * T
                + AC.sun_L0_c2 * T * T)
            .truncatingRemainder(dividingBy: 360)

        let M = (AC.sun_M_base.degrees
               + AC.sun_M_c1 * T
               + AC.sun_M_c2 * T * T)
            .truncatingRemainder(dividingBy: 360)
        let Mrad = Angle.degrees(M).radians

        let C = (AC.sun_C1_c0
               + AC.sun_C1_c1 * T
               + AC.sun_C1_c2 * T * T) * sin(Mrad)
              + (AC.sun_C2_c0
               + AC.sun_C2_c1 * T)     * sin(2 * Mrad)
              +  AC.sun_C3             * sin(3 * Mrad)

        let sunLon = L0 + C

        let omega = (AC.sun_omega_base.degrees
                   + AC.sun_omega_c1 * T)
            .truncatingRemainder(dividingBy: 360)
        let omegaRad = Angle.degrees(omega).radians

        let lambda = sunLon
                    + AC.sun_aberration
                    + AC.sun_nutation * sin(omegaRad)
        let result = Angle.degrees(lambda)
        longitudeCache = LongitudeCache(date: date, lambda: result)
        return result
    }

    /// Equatorial RA and Dec from ecliptic longitude.
    static func equatorialCoords(lambda: Angle) -> (ra: Angle, dec: Angle) {
        let eps = AstroConstants.obliquity.radians
        let ra  = atan2(cos(eps) * sin(lambda.radians), cos(lambda.radians))
        let dec = asin(sin(eps) * sin(lambda.radians))
        let raNorm = ra >= 0 ? ra : ra + .twoPi
        return (ra: .radians(raNorm), dec: .radians(dec))
    }

    // MARK: - Day anchors

    /// Approximate civil-twilight + solar-noon positions for the
    /// 24-hour day at `date` and `latDeg` (observer latitude in
    /// degrees). Pure spherical astronomy from the sun's declination
    /// — no WeatherKit, works for any date or latitude.
    ///
    /// Civil dawn / dusk are when the sun crosses altitude −6°.
    /// Solar noon is approximated as the local-clock midpoint of
    /// the day (12:00). Equation-of-time + longitude offset are
    /// ignored — they're at most ±15 min, well inside the visual
    /// gradient's resolution.
    ///
    /// Returns `nil` for the dawn / dusk fields during polar day
    /// (sun never sets) or polar night (sun never reaches −6°) at
    /// extreme latitudes / solstices.
    static func dayAnchors(for date: Date, latitude latDeg: Double) -> SunDayAnchors {
        let cal  = Calendar.current
        let noon = cal.startOfDay(for: date).addingTimeInterval(12 * 3600)

        let lambda          = eclipticLongitude(for: noon)
        let (_, decAngle)   = equatorialCoords(lambda: lambda)
        let dec             = decAngle.radians
        let phi             = latDeg * .pi / 180

        // Civil twilight altitude h₀ = −6°.
        // cos H = (sin h₀ − sin φ · sin δ) / (cos φ · cos δ)
        let civilAlt = -6.0 * .pi / 180
        let cosH     = (sin(civilAlt) - sin(phi) * sin(dec))
                     / (cos(phi) * cos(dec))

        guard cosH >= -1, cosH <= 1 else {
            return SunDayAnchors(civilDawnFraction: nil,
                                 solarNoonFraction: 0.5,
                                 civilDuskFraction: nil)
        }

        // Hour angle in radians (0…π), converted to a fraction of
        // a full 24-hour rotation.
        let h     = acos(cosH)
        let hFrac = h / (2 * .pi)
        return SunDayAnchors(
            civilDawnFraction: 0.5 - hFrac,
            solarNoonFraction: 0.5,
            civilDuskFraction: 0.5 + hFrac
        )
    }
}

// MARK: - SunDayAnchors

/// Time-of-day fractions (0…1) for the sun's three transition
/// points on a given date + latitude. Consumed by `LinearGradient`
/// factories to anchor the day-capsule gradient stops to the
/// observation's actual sunrise / sunset rather than fixed 25/75%.
struct SunDayAnchors {
    let civilDawnFraction: Double?
    let solarNoonFraction: Double
    let civilDuskFraction: Double?

    /// Fixed 25/50/75 stops — equivalent to "we don't know the
    /// observer's latitude / date". Used as the gradient fallback
    /// for `DayCapsule` callers that don't compute their own.
    static let `default` = SunDayAnchors(
        civilDawnFraction: 0.25,
        solarNoonFraction: 0.5,
        civilDuskFraction: 0.75
    )
}

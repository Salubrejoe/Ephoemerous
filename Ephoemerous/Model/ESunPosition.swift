import Foundation
import SwiftUI

enum ESunPosition {

    /// Apparent ecliptic longitude of the Sun (Meeus S25, low-precision).
    static func eclipticLongitude(for date: Date) -> Angle {
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
        return .degrees(lambda)
    }

    /// Equatorial RA and Dec from ecliptic longitude.
    static func equatorialCoords(lambda: Angle) -> (ra: Angle, dec: Angle) {
        let eps = AstroConstants.obliquity.radians
        let ra  = atan2(cos(eps) * sin(lambda.radians), cos(lambda.radians))
        let dec = asin(sin(eps) * sin(lambda.radians))
        let raNorm = ra >= 0 ? ra : ra + .twoPi
        return (ra: .radians(raNorm), dec: .radians(dec))
    }
}

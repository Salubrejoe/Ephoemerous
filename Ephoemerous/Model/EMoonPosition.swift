import Foundation
import SwiftUI
import simd

enum EMoonPosition {

    static func vector(for date: Date, siderealOffset: Angle) -> (vec: SIMD3<Double>, ra: Double, dec: Double) {
        let T = EPrecession.julianCenturies(from: date)
        let AC = AstroConstants.self

        let L0 = Angle.degrees((AC.moon_L0_base.degrees + AC.moon_L0_c1 * T)
                    .truncatingRemainder(dividingBy: 360)).radians
        let M  = Angle.degrees((AC.moon_M_base.degrees  + AC.moon_M_c1  * T)
                    .truncatingRemainder(dividingBy: 360)).radians
        let Ms = Angle.degrees((AC.moon_Ms_base.degrees + AC.moon_Ms_c1 * T)
                    .truncatingRemainder(dividingBy: 360)).radians
        let F  = Angle.degrees((AC.moon_F_base.degrees  + AC.moon_F_c1  * T)
                    .truncatingRemainder(dividingBy: 360)).radians
        let D  = Angle.degrees((AC.moon_D_base.degrees  + AC.moon_D_c1  * T)
                    .truncatingRemainder(dividingBy: 360)).radians

        var lam = L0 / (.pi / 180)
        lam += AC.moon_lam_ev  * sin(M);          lam += AC.moon_lam_var * sin(2*D - M)
        lam += AC.moon_lam_ann * sin(2*D);        lam += AC.moon_lam_A3  * sin(2*M)
        lam -= AC.moon_lam_A4  * sin(Ms);         lam -= AC.moon_lam_A5  * sin(2*F)
        lam += AC.moon_lam_A6  * sin(2*D - 2*M);  lam += AC.moon_lam_A7  * sin(2*D - Ms - M)
        lam += AC.moon_lam_A8  * sin(2*D + M);    lam += AC.moon_lam_A9  * sin(2*D - Ms)
        lam -= AC.moon_lam_A10 * sin(Ms - M);     lam -= AC.moon_lam_A11 * sin(D)
        lam -= AC.moon_lam_A12 * sin(Ms + M)

        var bet = 0.0
        bet += AC.moon_bet_B1 * sin(F);           bet += AC.moon_bet_B2 * sin(M + F)
        bet += AC.moon_bet_B3 * sin(M - F);       bet += AC.moon_bet_B4 * sin(2*D - F)
        bet += AC.moon_bet_B5 * sin(2*D + F - M); bet += AC.moon_bet_B6 * sin(2*D - F - M)
        bet += AC.moon_bet_B7 * sin(2*D + F)

        let lr  = Angle.degrees(lam).radians
        let br  = Angle.degrees(bet).radians
        let eps = AC.obliquity.radians

        let x = cos(br) * cos(lr)
        let y = cos(br) * sin(lr) * cos(eps) - sin(br) * sin(eps)
        let z = cos(br) * sin(lr) * sin(eps) + sin(br) * cos(eps)

        let ra  = atan2(y, x) * 180.0 / .pi
        let dec = asin(max(-1, min(1, z))) * 180.0 / .pi
        let vec = SIMD3<Double>(x, y, z).sidereallyRotated(by: siderealOffset)
        return (vec, ra < 0 ? ra + 360 : ra, dec)
    }

    static func illuminatedFraction(for date: Date) -> Double {
        let T  = EPrecession.julianCenturies(from: date)
        let AC = AstroConstants.self
        let D  = Angle.degrees((AC.moon_D_base.degrees  + AC.moon_D_c1  * T)
                    .truncatingRemainder(dividingBy: 360)).radians
        let M  = Angle.degrees((AC.moon_M_base.degrees  + AC.moon_M_c1  * T)
                    .truncatingRemainder(dividingBy: 360)).radians
        let Ms = Angle.degrees((AC.moon_Ms_base.degrees + AC.moon_Ms_c1 * T)
                    .truncatingRemainder(dividingBy: 360)).radians
        let i = 180.0
            - D / (.pi / 180)
            - AC.moon_phase_c1 * sin(M)
            + AC.moon_phase_c2 * sin(Ms)
            - AC.moon_phase_c3 * sin(2*D - M)
            - AC.moon_phase_c4 * sin(2*D)
            - AC.moon_phase_c5 * sin(2*M)
            - AC.moon_phase_c6 * sin(D)
        return (1.0 + cos(Angle.degrees(i).radians)) / 2.0
    }
}

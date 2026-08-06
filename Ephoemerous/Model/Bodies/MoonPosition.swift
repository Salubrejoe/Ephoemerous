import Foundation
import SwiftUI
import simd

enum MoonPosition {

    // MARK: - Per-frame cache
    //
    // EMoonLayer calls `vector(for:siderealOffset:)` every draw and
    // the result depends on both `date` (the orbital series) and
    // `siderealOffset` (the final rotation that puts the moon in
    // canvas coordinates). Single-entry cache keyed on both: hits on
    // pan/zoom (neither input changes), misses on time scrub or
    // location animation (correct — the sky should update live).
    // Main-thread-only by canvas contract.
    private struct VectorCache {
        let date:           Date
        let siderealOffset: Angle
        let vec:            SIMD3<Double>
        let ra:             Double
        let dec:            Double
    }
    nonisolated(unsafe) private static var vectorCache: VectorCache?

    static func vector(for date: Date, siderealOffset: Angle) -> (vec: SIMD3<Double>, ra: Double, dec: Double) {
        if let c = vectorCache,
           c.date == date,
           c.siderealOffset == siderealOffset {
            return (c.vec, c.ra, c.dec)
        }

        let T = Precession.julianCenturies(from: date)
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
        let normRA = ra < 0 ? ra + 360 : ra
        vectorCache = VectorCache(date:           date,
                                  siderealOffset: siderealOffset,
                                  vec:            vec,
                                  ra:             normRA,
                                  dec:            dec)
        return (vec, normRA, dec)
    }

    // Called every frame from the moon layer to pick the phase glyph.
    // Same cache rationale as `vector(for:siderealOffset:)`.
    private struct IlluminationCache {
        let date:     Date
        let fraction: Double
        let isWaxing: Bool
    }
    nonisolated(unsafe) private static var illuminationCache: IlluminationCache?

    static func illuminatedFraction(for date: Date) -> Double {
        illumination(for: date).fraction
    }

    /// Illuminated fraction 0…1 AND which way the Moon is heading.
    ///
    /// The waxing bit used to be thrown away here, which made every
    /// phase render symmetric — a waning gibbous drew as a waxing one,
    /// mirrored, for half of every month (see `Artist.moonPhaseSymbol`,
    /// whose comment admitted as much). It costs nothing to keep: `D`,
    /// the Moon's mean elongation from the Sun, is already computed on
    /// the way to the phase angle. D in 0…180° is waxing — the Moon is
    /// pulling east of the Sun into the evening sky — and 180…360° is
    /// waning. `sin(D) >= 0` says exactly that without unwrapping.
    static func illumination(for date: Date) -> (fraction: Double, isWaxing: Bool) {
        if let c = illuminationCache, c.date == date { return (c.fraction, c.isWaxing) }

        let T  = Precession.julianCenturies(from: date)
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
        let fraction = (1.0 + cos(Angle.degrees(i).radians)) / 2.0
        let isWaxing = sin(D) >= 0
        illuminationCache = IlluminationCache(date: date, fraction: fraction, isWaxing: isWaxing)
        return (fraction, isWaxing)
    }

    /// The Moon as it is actually SEEN from a given latitude — what the
    /// badge draws.
    static func phase(for date: Date, latitude: Angle) -> LunarPhase {
        let (fraction, isWaxing) = illumination(for: date)
        return LunarPhase(illuminatedFraction: fraction,
                         isWaxing:            isWaxing,
                         southernView:        latitude.degrees < 0)
    }
}

// MARK: - LunarPhase
// What the Moon looks like right now, from where you are standing.
//
// The hemisphere flag is not a detail. A waxing crescent is lit on the
// RIGHT from Florence and on the LEFT from Sydney — the observer is
// upside down relative to the other hemisphere, so the whole phase
// mirrors. Getting this wrong is the same class of northern-bias bug as
// the projection frame's hardcoded pole, and just as invisible from
// Europe.
struct LunarPhase: Equatable {
    /// 0 = new, 1 = full.
    let illuminatedFraction: Double
    /// Heading toward full. Waning is the mirror image.
    let isWaxing:            Bool
    /// Observer is in the southern hemisphere, so the phase flips.
    let southernView:        Bool

    /// Which limb carries the light. Two flips cancel: a southern
    /// observer watching a waning moon sees it lit on the same side as a
    /// northern observer watching a waxing one.
    var litOnTrailingSide: Bool { isWaxing != southernView }

    /// Below this there is no lit sliver worth drawing and the badge
    /// falls back to an unfilled outline — see `MoonPhaseShape`.
    static let newMoonThreshold: Double = 0.03

    var isNew: Bool { illuminatedFraction < Self.newMoonThreshold }

    /// The canonical eight, named correctly.
    ///
    /// The fraction is SYMMETRIC — it runs 0→1→0 across a lunation, so it
    /// cannot name a phase on its own, and the table that tried to (walking
    /// 0…1 straight through all eight names in order) got most of the month
    /// wrong: a true quarter moon at f≈0.5 came out "Full Moon", f≈0.9 came
    /// out "Waning Crescent", and a real full moon at f≈1.0 fell off the end
    /// of the table into "unknown". Half the answer was always the waxing
    /// bit, which nothing was carrying.
    var name: String {
        let f = illuminatedFraction
        if f < 0.02 { return Strings.MoonPhase.newMoon }
        if f > 0.98 { return Strings.MoonPhase.fullMoon }
        if f < 0.48 { return isWaxing ? Strings.MoonPhase.waxingCrescent
                                      : Strings.MoonPhase.waningCrescent }
        if f < 0.52 { return isWaxing ? Strings.MoonPhase.firstQuarter
                                      : Strings.MoonPhase.lastQuarter }
        return isWaxing ? Strings.MoonPhase.waxingGibbous
                        : Strings.MoonPhase.waningGibbous
    }

    /// Matching glyph from the `moonphase.*` family. Now that waxing is
    /// known, the waning half gets its own correctly-mirrored symbols
    /// instead of borrowing the waxing ones.
    var symbol: Symbol {
        let f = illuminatedFraction
        if f < 0.02 { return .moonNew }
        if f > 0.98 { return .moonFull }
        if f < 0.48 { return isWaxing ? .moonWaxingCrescent : .moonWaningCrescent }
        if f < 0.52 { return isWaxing ? .moonFirstQuarter   : .moonLastQuarter }
        return isWaxing ? .moonWaxingGibbous : .moonWaningGibbous
    }
}

import Foundation
import SwiftUI
import simd

// MARK: - VSOP87 truncated heliocentric positions (Meeus Ch 31-37)
// L, B in radians; R in AU. Accuracy ~1 arc-minute for bright planets.
enum EPlanetPosition {

    private static let eps = 23.4393 * Double.pi / 180.0

    private static func toVector(L: Double, B: Double, siderealOffset: Angle) -> (vec: SIMD3<Double>, ra: Double, dec: Double) {
        let x = cos(B) * cos(L)
        let y = cos(B) * sin(L) * cos(eps) - sin(B) * sin(eps)
        let z = cos(B) * sin(L) * sin(eps) + sin(B) * cos(eps)
        let ra  = atan2(y, x) * 180.0 / .pi
        let dec = asin(max(-1, min(1, z))) * 180.0 / .pi
        let vec = SIMD3<Double>(x, y, z).sidereallyRotated(by: siderealOffset)
        return (vec, ra < 0 ? ra + 360 : ra, dec)
    }

    private static func geocentric(Lp: Double, Bp: Double, Rp: Double,
                                   Ls: Double, Rs: Double) -> (L: Double, B: Double) {
        let x = Rp * cos(Bp) * cos(Lp) - Rs * cos(Ls)
        let y = Rp * cos(Bp) * sin(Lp) - Rs * sin(Ls)
        let z = Rp * sin(Bp)
        let L = atan2(y, x).truncatingRemainder(dividingBy: 2 * .pi)
        let B = atan2(z, sqrt(x*x + y*y))
        return (L < 0 ? L + 2 * .pi : L, B)
    }

    private static func earth(_ T: Double) -> (L: Double, R: Double) {
        let tau = T / 10.0
        let L0 = 175347046.0
            + 3341656.0  * cos(4.6709623 + 6283.0758500 * tau)
            + 34894.0    * cos(4.62610   + 12566.15170  * tau)
        let L1 = 628331966747.0
            + 206059.0   * cos(2.678235  + 6283.07585   * tau)
        let L = ((L0 + L1 * tau) * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        let R0 = 100013989.0
            + 1670700.0  * cos(3.0984635 + 6283.0758500 * tau)
        let R = R0 * 1e-8
        return (L < 0 ? L + 2 * .pi : L, R)
    }

    private static func mercury(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 440250710.0
            + 40989415.0 * cos(1.4864338  + 26087.9031416 * tau)
            + 5046294.0  * cos(4.4778549  + 52175.8062831 * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        let B = (217347.0 * cos(3.0 + 26087.9 * tau)
               + 44145.0  * cos(3.0 + 52175.8 * tau)) * 1e-8
        let R = (39528272.0 + 7834132.0 * cos(6.1923372 + 26087.903142 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    private static func venus(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 317614667.0
            + 1353968.0  * cos(5.5931332  + 10213.2855462 * tau)
            + 89892.0    * cos(5.30650    + 20426.57109   * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        let B = (5923638.0 * cos(0.2670278 + 10213.2855462 * tau)
               + 40108.0   * cos(1.14737   + 20426.571092  * tau)) * 1e-8
        let R = (72334821.0 + 489824.0 * cos(4.021518 + 10213.285546 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    private static func mars(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 1223514352.0
            + 40660012.0 * cos(6.0538088  + 3340.6124267  * tau)
            + 1108170.0  * cos(5.717756   + 6681.224853   * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        let B = (3197135.0 * cos(3.7683204 + 3340.6124267 * tau)
               + 298033.0  * cos(4.10677   + 6681.224853  * tau)) * 1e-8
        let R = (152699551.0 + 14184953.0 * cos(3.47971284 + 3340.6124267 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    private static func jupiter(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 599471033.0
            + 52993480.0 * cos(0.2467248  + 529.6909651   * tau)
            + 1834243.0  * cos(4.846420   + 1059.381930   * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        let B = (2278192.0 * cos(4.1788839 + 529.6909651 * tau)
               + 67799.0   * cos(3.559474  + 1059.381930  * tau)) * 1e-8
        let R = (520887429.0 + 25209327.0 * cos(3.49108289 + 529.6909651 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    private static func saturn(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 874016757.0
            + 21413299.0 * cos(3.2411768  + 213.2990954   * tau)
            + 1414024.0  * cos(4.582039   + 7.113547      * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        let B = (4330678.0 * cos(3.6028443 + 213.2990954 * tau)
               + 240348.0  * cos(2.852385  + 426.598191   * tau)) * 1e-8
        let R = (955758136.0 + 52921382.0 * cos(2.39226220 + 213.2990954 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    private static func uranus(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 548129294.0
            + 7502543.0  * cos(6.1580358  + 74.7815986    * tau)
            + 511559.0   * cos(2.300041   + 149.563197    * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        let B = (1346277.0 * cos(2.6187781 + 74.7815986 * tau)
               + 62341.0   * cos(5.081806  + 149.563197  * tau)) * 1e-8
        let R = (1922879639.0 + 88784984.0 * cos(5.60737913 + 74.7815986 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    private static func neptune(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 531188633.0
            + 3606985.0  * cos(4.4400216  + 38.1330356    * tau)
            + 253332.0   * cos(5.782312   + 76.266071     * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        let B = (3088622.0 * cos(1.4415852 + 38.1330356 * tau)
               + 27050.0   * cos(5.433864  + 76.266071   * tau)) * 1e-8
        let R = (3007013205.0 + 27062259.0 * cos(5.24270 + 38.1330356 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    static func allVectors(for date: Date, siderealOffset: Angle) -> [(planet: EPlanet, vec: SIMD3<Double>, ra: Double, dec: Double)] {
        let T = EPrecession.julianCenturies(from: date)
        let (eLon, eR) = earth(T)
        let heliocentric = [mercury(T), venus(T), mars(T), jupiter(T), saturn(T), uranus(T), neptune(T)]
        return zip(EPlanet.all, heliocentric).map { planet, h in
            let (gL, gB) = geocentric(Lp: h.0, Bp: h.1, Rp: h.2, Ls: eLon, Rs: eR)
            let (vec, ra, dec) = toVector(L: gL, B: gB, siderealOffset: siderealOffset)
            return (planet, vec, ra, dec)
        }
    }
}

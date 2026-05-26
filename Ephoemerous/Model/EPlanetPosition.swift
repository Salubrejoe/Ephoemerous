import Foundation
import SwiftUI
import simd

// MARK: - Heliocentric positions via VSOP87D
//
// Series from Meeus, Astronomical Algorithms 2nd ed., Appendix III (truncated
// VSOP87D, referred to ecliptic and equinox of date). Each series is
//     Σᵢ Aᵢ · cos(Bᵢ + Cᵢ · τ)        with τ = (JD − 2451545.0) / 365250
// (Julian millennia from J2000.0). The full longitude is built as
//     L = (L0(τ) + L1(τ)·τ + L2(τ)·τ²) × 1e-8        radians
// and similarly for B and R. The L1·τ secular term is what carries the mean
// motion — without it the planets do not actually orbit.
//
// Truncations are short. Position errors land within ~degree for the inner
// planets and a few arc-minutes for the outer ones. Fine for naked-eye
// plotting; not for ephemeris work.
enum EPlanetPosition {

    fileprivate typealias Term = (A: Double, B: Double, C: Double)

    private static func sum(_ terms: [Term], _ tau: Double) -> Double {
        terms.reduce(0) { $0 + $1.A * cos($1.B + $1.C * tau) }
    }

    private static func wrap(_ x: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: 2 * .pi)
        return r < 0 ? r + 2 * .pi : r
    }

    /// Mean obliquity of the ecliptic of date, in radians (Meeus eq. 22.2).
    private static func meanObliquity(_ T: Double) -> Double {
        let arcsec  = -46.8150 * T - 0.00059 * T * T + 0.001813 * T * T * T
        let degrees =  23.4392911 + arcsec / 3600.0
        return degrees * .pi / 180.0
    }

    private static func toVector(L: Double, B: Double, eps: Double,
                                 siderealOffset: Angle)
        -> (vec: SIMD3<Double>, ra: Double, dec: Double)
    {
        let x   = cos(B) * cos(L)
        let y   = cos(B) * sin(L) * cos(eps) - sin(B) * sin(eps)
        let z   = cos(B) * sin(L) * sin(eps) + sin(B) * cos(eps)
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
        let L = wrap((sum(Earth_L0, tau)
                    + sum(Earth_L1, tau) * tau
                    + sum(Earth_L2, tau) * tau * tau) * 1e-8)
        let R = (sum(Earth_R0, tau) + sum(Earth_R1, tau) * tau) * 1e-8
        return (L, R)
    }

    private static func mercury(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        let L = wrap((sum(Mercury_L0, tau)
                    + sum(Mercury_L1, tau) * tau
                    + sum(Mercury_L2, tau) * tau * tau) * 1e-8)
        let B = (sum(Mercury_B0, tau) + sum(Mercury_B1, tau) * tau) * 1e-8
        let R = (sum(Mercury_R0, tau) + sum(Mercury_R1, tau) * tau) * 1e-8
        return (L, B, R)
    }

    private static func venus(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        let L = wrap((sum(Venus_L0, tau)
                    + sum(Venus_L1, tau) * tau
                    + sum(Venus_L2, tau) * tau * tau) * 1e-8)
        let B = (sum(Venus_B0, tau) + sum(Venus_B1, tau) * tau) * 1e-8
        let R = (sum(Venus_R0, tau) + sum(Venus_R1, tau) * tau) * 1e-8
        return (L, B, R)
    }

    private static func mars(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        let L = wrap((sum(Mars_L0, tau)
                    + sum(Mars_L1, tau) * tau
                    + sum(Mars_L2, tau) * tau * tau) * 1e-8)
        let B = (sum(Mars_B0, tau) + sum(Mars_B1, tau) * tau) * 1e-8
        let R = (sum(Mars_R0, tau) + sum(Mars_R1, tau) * tau) * 1e-8
        return (L, B, R)
    }

    private static func jupiter(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        let L = wrap((sum(Jupiter_L0, tau)
                    + sum(Jupiter_L1, tau) * tau
                    + sum(Jupiter_L2, tau) * tau * tau) * 1e-8)
        let B = (sum(Jupiter_B0, tau) + sum(Jupiter_B1, tau) * tau) * 1e-8
        let R = (sum(Jupiter_R0, tau) + sum(Jupiter_R1, tau) * tau) * 1e-8
        return (L, B, R)
    }

    private static func saturn(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        let L = wrap((sum(Saturn_L0, tau)
                    + sum(Saturn_L1, tau) * tau
                    + sum(Saturn_L2, tau) * tau * tau) * 1e-8)
        let B = (sum(Saturn_B0, tau) + sum(Saturn_B1, tau) * tau) * 1e-8
        let R = (sum(Saturn_R0, tau) + sum(Saturn_R1, tau) * tau) * 1e-8
        return (L, B, R)
    }

    private static func uranus(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        let L = wrap((sum(Uranus_L0, tau)
                    + sum(Uranus_L1, tau) * tau
                    + sum(Uranus_L2, tau) * tau * tau) * 1e-8)
        let B = (sum(Uranus_B0, tau) + sum(Uranus_B1, tau) * tau) * 1e-8
        let R = (sum(Uranus_R0, tau) + sum(Uranus_R1, tau) * tau) * 1e-8
        return (L, B, R)
    }

    private static func neptune(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        let L = wrap((sum(Neptune_L0, tau)
                    + sum(Neptune_L1, tau) * tau
                    + sum(Neptune_L2, tau) * tau * tau) * 1e-8)
        let B = (sum(Neptune_B0, tau) + sum(Neptune_B1, tau) * tau) * 1e-8
        let R = (sum(Neptune_R0, tau) + sum(Neptune_R1, tau) * tau) * 1e-8
        return (L, B, R)
    }

    static func allVectors(for date: Date, siderealOffset: Angle)
        -> [(planet: EPlanet, vec: SIMD3<Double>, ra: Double, dec: Double)]
    {
        let T = EPrecession.julianCenturies(from: date)
        let eps = meanObliquity(T)
        let (eLon, eR) = earth(T)
        let heliocentric = [mercury(T), venus(T), mars(T), jupiter(T),
                            saturn(T), uranus(T), neptune(T)]
        return zip(EPlanet.all, heliocentric).map { planet, h in
            let (gL, gB) = geocentric(Lp: h.0, Bp: h.1, Rp: h.2, Ls: eLon, Rs: eR)
            let (vec, ra, dec) = toVector(L: gL, B: gB, eps: eps,
                                          siderealOffset: siderealOffset)
            return (planet, vec, ra, dec)
        }
    }
}

// MARK: - VSOP87D truncated series (Meeus Appendix III)
private extension EPlanetPosition {

    // -------- Mercury --------
    static let Mercury_L0: [Term] = [
        (440_250_710.0, 0.0,        0.0            ),
        ( 40_989_415.0, 1.48302034, 26_087.9031416 ),
        (  5_046_294.0, 4.47785449, 52_175.8062831 ),
        (    855_347.0, 1.16520322, 78_263.7094247 ),
        (    165_590.0, 4.11969163,104_351.6125663 ),
        (     34_562.0, 4.69072301,130_439.5157079 ),
    ]
    static let Mercury_L1: [Term] = [
        (2_608_790_314_157.0, 0.0,        0.0            ),
        (        1_126_008.0, 6.21703970, 26_087.9031416 ),
        (          303_471.0, 3.05565472, 52_175.8062831 ),
        (           80_538.0, 6.10454743, 78_263.7094247 ),
    ]
    static let Mercury_L2: [Term] = [
        (53_050.0, 0.0,        0.0            ),
        (16_904.0, 4.69072301, 26_087.9031416 ),
    ]
    static let Mercury_B0: [Term] = [
        (11_737_529.0, 1.98357499, 26_087.9031416 ),
        ( 2_388_077.0, 5.03738959, 52_175.8062831 ),
        ( 1_222_840.0, 3.14159265,  0.0           ),
        (   543_252.0, 1.79644363, 78_263.7094247 ),
        (   129_779.0, 4.83232504,104_351.6125663 ),
    ]
    static let Mercury_B1: [Term] = [
        (429_151.0, 3.50169974, 26_087.9031416 ),
        (146_234.0, 3.14159265,  0.0           ),
        ( 22_675.0, 0.01515380, 52_175.8062831 ),
    ]
    static let Mercury_R0: [Term] = [
        (39_528_272.0, 0.0,        0.0            ),
        ( 7_834_132.0, 6.19233851, 26_087.9031416 ),
        (   795_526.0, 2.95989700, 52_175.8062831 ),
        (   121_282.0, 6.01064377, 78_263.7094247 ),
    ]
    static let Mercury_R1: [Term] = [
        (217_348.0, 4.65617292, 26_087.9031416 ),
        ( 44_142.0, 1.42385544, 52_175.8062831 ),
        ( 10_094.0, 4.47466326, 78_263.7094247 ),
    ]

    // -------- Venus --------
    static let Venus_L0: [Term] = [
        (317_614_667.0, 0.0,        0.0            ),
        (  1_353_968.0, 5.59313319, 10_213.2855462 ),
        (     89_892.0, 5.30650048, 20_426.5710924 ),
        (      5_477.0, 4.41633056,  7_860.4193924 ),
        (      3_456.0, 2.69247483, 11_790.6290887 ),
    ]
    static let Venus_L1: [Term] = [
        (1_021_352_943_053.0, 0.0,        0.0            ),
        (           95_708.0, 2.46424448, 10_213.2855462 ),
        (           14_445.0, 0.51625264, 20_426.5710924 ),
    ]
    static let Venus_L2: [Term] = [
        (54_127.0, 0.0,        0.0            ),
        ( 3_891.0, 0.34543367, 10_213.2855462 ),
    ]
    static let Venus_B0: [Term] = [
        (5_923_638.0, 0.26702775, 10_213.2855462 ),
        (   40_108.0, 1.14737178, 20_426.5710924 ),
        (   32_815.0, 3.14159265,  0.0           ),
    ]
    static let Venus_B1: [Term] = [
        (287_821.0, 1.88964962, 10_213.2855462 ),
        (  3_496.0, 3.14159265,  0.0           ),
    ]
    static let Venus_R0: [Term] = [
        (72_334_821.0, 0.0,        0.0            ),
        (   489_824.0, 4.02151832, 10_213.2855462 ),
        (     1_658.0, 4.90206728, 20_426.5710924 ),
        (     1_632.0, 2.84548851,  7_860.4193924 ),
    ]
    static let Venus_R1: [Term] = [
        (34_551.0, 0.89198706, 10_213.2855462 ),
        (   234.0, 1.77224384, 20_426.5710924 ),
    ]

    // -------- Earth --------
    static let Earth_L0: [Term] = [
        (175_347_046.0, 0.0,        0.0           ),
        (  3_341_656.0, 4.66925680,  6_283.0758500),
        (     34_894.0, 4.62610242, 12_566.1517000),
        (      3_497.0, 2.74411800,  5_753.3848849),
        (      3_418.0, 2.82886579,      3.5231087),
    ]
    static let Earth_L1: [Term] = [
        (628_331_966_747.0, 0.0,        0.0           ),
        (        206_059.0, 2.67823455,  6_283.0758500),
        (          4_303.0, 2.63512650, 12_566.1517000),
    ]
    static let Earth_L2: [Term] = [
        (52_919.0, 0.0,        0.0           ),
        ( 8_720.0, 1.07209706,  6_283.0758500),
        (    309.0, 0.86728818, 12_566.1517000),
    ]
    static let Earth_R0: [Term] = [
        (100_013_989.0, 0.0,        0.0           ),
        (  1_670_700.0, 3.09846351,  6_283.0758500),
        (     13_956.0, 3.05524200, 12_566.1517000),
        (      3_084.0, 5.19846675, 77_713.7714681),
    ]
    static let Earth_R1: [Term] = [
        (103_019.0, 1.10748970,  6_283.0758500),
        (  1_721.0, 1.06442300, 12_566.1517000),
    ]

    // -------- Mars --------
    static let Mars_L0: [Term] = [
        (620_347_712.0, 0.0,        0.0           ),
        ( 18_656_368.0, 5.05037100,  3_340.6124267),
        (  1_108_217.0, 5.40099836,  6_681.2248534),
        (     91_798.0, 5.75479911, 10_021.8372801),
        (     27_745.0, 5.97049553,      3.5231087),
    ]
    static let Mars_L1: [Term] = [
        (334_085_627_474.0, 0.0,        0.0           ),
        (      1_458_227.0, 3.60426468,  3_340.6124267),
        (        164_901.0, 3.92631251,  6_681.2248534),
    ]
    static let Mars_L2: [Term] = [
        (58_016.0, 2.04979463,  3_340.6124267),
        (54_188.0, 0.0,        0.0           ),
        (13_908.0, 2.45742393,  6_681.2248534),
    ]
    static let Mars_B0: [Term] = [
        (3_197_135.0, 3.76832042,  3_340.6124267),
        (  298_033.0, 4.10616996,  6_681.2248534),
        (  289_105.0, 3.14159265,  0.0          ),
        (   31_366.0, 4.44651049, 10_021.8372801),
    ]
    static let Mars_B1: [Term] = [
        (350_069.0, 5.36847091,  3_340.6124267),
        ( 14_116.0, 3.14159265,  0.0          ),
        (  9_671.0, 5.47877583,  6_681.2248534),
    ]
    static let Mars_R0: [Term] = [
        (153_033_488.0, 0.0,        0.0           ),
        ( 14_184_953.0, 3.47971284,  3_340.6124267),
        (    660_776.0, 3.81783443,  6_681.2248534),
        (     46_179.0, 4.15595316, 10_021.8372801),
    ]
    static let Mars_R1: [Term] = [
        (1_107_433.0, 2.03250524, 3_340.6124267),
        (  103_176.0, 2.37071847, 6_681.2248534),
        (   12_877.0, 0.0,        0.0          ),
    ]

    // -------- Jupiter --------
    static let Jupiter_L0: [Term] = [
        (59_954_691.0, 0.0,        0.0          ),
        ( 9_695_898.0, 5.06191793,   529.6909651),
        (   573_610.0, 1.44406206,     7.1135470),
        (   306_389.0, 5.41734730, 1_059.3819302),
        (    97_178.0, 4.14264726,   632.7837393),
        (    72_903.0, 3.64042909,   522.5774181),
    ]
    static let Jupiter_L1: [Term] = [
        (52_993_480_757.0, 0.0,        0.0          ),
        (       489_741.0, 4.22066689,   529.6909651),
        (       228_919.0, 6.02647464,     7.1135470),
        (        27_655.0, 4.57265956, 1_059.3819302),
        (        20_721.0, 5.45938936,   522.5774181),
    ]
    static let Jupiter_L2: [Term] = [
        (47_234.0, 4.32148860,     7.1135470),
        (30_671.0, 0.0,        0.0          ),
        (24_077.0, 4.27490681, 1_059.3819302),
        (12_338.0, 6.04074808,   529.6909651),
    ]
    static let Jupiter_B0: [Term] = [
        (2_268_616.0, 3.55852607,   529.6909651),
        (  110_090.0, 0.0,        0.0          ),
        (  109_972.0, 3.90809347, 1_059.3819302),
        (    8_101.0, 3.60509573,   522.5774181),
        (    6_438.0, 0.30903809,   536.8045121),
    ]
    static let Jupiter_B1: [Term] = [
        (177_352.0, 5.70166488,   529.6909651),
        (  3_230.0, 5.77941200, 1_059.3819302),
        (  3_081.0, 5.47464296,   522.5774181),
    ]
    static let Jupiter_R0: [Term] = [
        (520_887_429.0, 0.0,        0.0          ),
        ( 25_209_327.0, 3.49108640,   529.6909651),
        (    610_600.0, 3.84115365, 1_059.3819302),
        (    282_029.0, 2.57419879,   632.7837393),
        (    187_647.0, 2.07590380,   522.5774181),
    ]
    static let Jupiter_R1: [Term] = [
        (1_271_802.0, 2.64937511,   529.6909651),
        (   61_662.0, 3.00076251, 1_059.3819302),
        (   53_444.0, 3.89717644,   522.5774181),
    ]

    // -------- Saturn --------
    static let Saturn_L0: [Term] = [
        (87_401_354.0, 0.0,        0.0          ),
        (11_107_660.0, 3.96205090, 213.2990954  ),
        ( 1_414_151.0, 4.58581516,   7.1135470  ),
        (   398_379.0, 0.52112032, 206.1855484  ),
        (   350_769.0, 3.30329094, 426.5981909  ),
    ]
    static let Saturn_L1: [Term] = [
        (21_354_295_596.0, 0.0,        0.0          ),
        (     1_296_855.0, 1.82820545, 213.2990954  ),
        (       564_348.0, 2.88500136,   7.1135470  ),
        (       107_679.0, 2.27769150, 206.1855484  ),
    ]
    static let Saturn_L2: [Term] = [
        (116_441.0, 1.17988132,   7.1135470  ),
        ( 91_921.0, 0.07425253, 213.2990954  ),
        ( 90_592.0, 0.0,        0.0          ),
    ]
    static let Saturn_B0: [Term] = [
        (4_330_678.0, 3.60284428, 213.2990954  ),
        (  240_348.0, 2.85238489, 426.5981909  ),
        (   84_746.0, 0.0,        0.0          ),
        (   34_116.0, 0.57297307, 206.1855484  ),
    ]
    static let Saturn_B1: [Term] = [
        (397_555.0, 5.33289992, 213.2990954  ),
        ( 49_479.0, 3.14159265,   0.0        ),
        ( 18_572.0, 6.09919206, 426.5981909  ),
    ]
    static let Saturn_R0: [Term] = [
        (955_758_136.0, 0.0,        0.0          ),
        ( 52_921_382.0, 2.39226220, 213.2990954  ),
        (  1_873_680.0, 5.23549605, 206.1855484  ),
        (  1_464_664.0, 1.64763046, 426.5981909  ),
    ]
    static let Saturn_R1: [Term] = [
        (6_182_981.0, 0.25843534, 213.2990954  ),
        (  506_578.0, 0.71114627, 206.1855484  ),
        (  341_394.0, 5.79635741, 426.5981909  ),
    ]

    // -------- Uranus --------
    static let Uranus_L0: [Term] = [
        (548_129_295.0, 0.0,        0.0         ),
        (  9_260_408.0, 0.89106421, 74.7815986  ),
        (  1_504_248.0, 3.62719261,  1.4844727  ),
        (    365_982.0, 1.89962183, 73.2971259  ),
        (    272_328.0, 3.35823711,149.5631971  ),
    ]
    static let Uranus_L1: [Term] = [
        (7_478_165_903.0, 0.0,        0.0         ),
        (      154_458.0, 5.24201658, 74.7815986  ),
        (       24_456.0, 1.71255705,  1.4844727  ),
        (        9_258.0, 0.42844620, 11.0457003  ),
    ]
    static let Uranus_L2: [Term] = [
        (53_033.0, 0.0,        0.0         ),
        ( 2_358.0, 2.26014918, 74.7815986  ),
    ]
    static let Uranus_B0: [Term] = [
        (1_346_278.0, 2.61877810,  74.7815986 ),
        (   62_341.0, 5.08111171, 149.5631971 ),
        (   61_601.0, 3.14159265,   0.0       ),
        (    9_964.0, 1.61603876,  76.2660713 ),
    ]
    static let Uranus_B1: [Term] = [
        (206_366.0, 4.12394311,  74.7815986 ),
        (  8_563.0, 0.33812257, 149.5631971 ),
    ]
    static let Uranus_R0: [Term] = [
        (1_921_264_848.0, 0.0,        0.0         ),
        (   88_784_984.0, 5.60377527, 74.7815986  ),
        (    3_440_836.0, 0.32836099, 73.2971259  ),
        (    2_055_653.0, 1.78295159,149.5631971  ),
    ]
    static let Uranus_R1: [Term] = [
        (1_479_896.0, 3.67205705,  74.7815986 ),
        (   71_212.0, 6.22601007,  63.7358983 ),
        (   68_627.0, 6.13411478, 149.5631971 ),
    ]

    // -------- Neptune --------
    static let Neptune_L0: [Term] = [
        (531_188_633.0, 0.0,        0.0         ),
        (  1_798_476.0, 2.90101273, 38.1330356  ),
        (  1_019_728.0, 0.48580922,  1.4844727  ),
        (    124_532.0, 4.83008090, 36.6485629  ),
        (     42_064.0, 5.41054993,  2.9689454  ),
    ]
    static let Neptune_L1: [Term] = [
        (3_813_297_232.0, 0.0,        0.0         ),
        (       16_604.0, 4.86319127,  1.4844727  ),
        (       15_807.0, 2.27923488, 38.1330356  ),
    ]
    static let Neptune_L2: [Term] = [
        (53_893.0, 0.0,        0.0         ),
        (    296.0, 1.85501516,  1.4844727  ),
    ]
    static let Neptune_B0: [Term] = [
        (3_088_623.0, 1.44104373, 38.1330356  ),
        (   27_780.0, 5.91271882, 76.2660713  ),
        (   27_624.0, 0.0,        0.0         ),
        (   15_448.0, 3.50877080, 39.6175083  ),
    ]
    static let Neptune_B1: [Term] = [
        (227_279.0, 3.80793089, 38.1330356  ),
        (  1_803.0, 1.97576794, 76.2660713  ),
    ]
    static let Neptune_R0: [Term] = [
        (3_007_013_206.0, 0.0,        0.0         ),
        (   27_062_259.0, 1.32999458, 38.1330356  ),
        (    1_691_764.0, 3.25186138, 36.6485629  ),
        (      807_831.0, 5.18592836,  1.4844727  ),
    ]
    static let Neptune_R1: [Term] = [
        (236_339.0, 0.70498000, 38.1330356  ),
        ( 13_220.0, 3.32026422,  1.4844727  ),
    ]
}

import SwiftUI
import simd

// MARK: - Planet data

struct EPlanet {
    let name: String
    let color: Color
    /// Approximate visual magnitude at mean distance (used to size the dot)
    let baseMagnitude: Double
}

// MARK: - VSOP87 truncated heliocentric longitude/latitude (Meeus Ch 31-36)
// L, B in radians; R in AU. Accuracy ~1 arc-minute for bright planets.
enum EPlanetPosition {

    // Shared Sun mean anomaly
    private static func sunM(_ T: Double) -> Double {
        let deg = Double.pi / 180.0
        return (357.5291092 + 35999.0502909 * T).truncatingRemainder(dividingBy: 360) * deg
    }

    // Obliquity of ecliptic
    private static let eps = 23.4393 * Double.pi / 180.0

    // Convert ecliptic L,B (radians) to equatorial unit vector, siderally rotated
    private static func toVector(L: Double, B: Double, siderealOffset: Angle) -> (vec: SIMD3<Double>, ra: Double, dec: Double) {
        let x = cos(B) * cos(L)
        let y = cos(B) * sin(L) * cos(eps) - sin(B) * sin(eps)
        let z = cos(B) * sin(L) * sin(eps) + sin(B) * cos(eps)
        let ra  = atan2(y, x) * 180.0 / .pi
        let dec = asin(max(-1, min(1, z))) * 180.0 / .pi
        let vec = SIMD3<Double>(x, y, z).sidereallyRotated(by: siderealOffset)
        return (vec, ra < 0 ? ra + 360 : ra, dec)
    }

    // Geocentric ecliptic from heliocentric planet + Sun position
    // Returns (L_geo, B_geo) in radians
    private static func geocentric(Lp: Double, Bp: Double, Rp: Double,
                                   Ls: Double, Rs: Double) -> (L: Double, B: Double) {
        let x = Rp * cos(Bp) * cos(Lp) - Rs * cos(Ls)
        let y = Rp * cos(Bp) * sin(Lp) - Rs * sin(Ls)
        let z = Rp * sin(Bp)
        let L = atan2(y, x).truncatingRemainder(dividingBy: 2 * .pi)
        let B = atan2(z, sqrt(x*x + y*y))
        return (L < 0 ? L + 2 * .pi : L, B)
    }

    // Earth heliocentric L, R (Meeus Table 32.A truncated)
    private static func earth(_ T: Double) -> (L: Double, R: Double) {
        let tau = T / 10.0
        let L0 = 175347046.0
           + 3341656.0  * cos(4.6709623 + 6283.0758500 * tau)
           + 34894.0    * cos(4.62610   + 12566.15170  * tau)
           + 3497.0     * cos(2.7441    + 5753.3849    * tau)
           + 3418.0     * cos(2.8289    + 3.5231       * tau)
           + 3136.0     * cos(3.6277    + 77713.7715   * tau)
           + 2676.0     * cos(4.4181    + 7860.4194    * tau)
           + 2343.0     * cos(6.1352    + 3930.2097    * tau)
        let L1 = 628331966747.0
           + 206059.0   * cos(2.678235  + 6283.07585   * tau)
           + 4303.0     * cos(2.6351    + 12566.1517   * tau)
        let L = ((L0 + L1 * tau) * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        let R0 = 100013989.0
           + 1670700.0  * cos(3.0984635 + 6283.0758500 * tau)
           + 13956.0    * cos(3.05525   + 12566.15170  * tau)
           + 3084.0     * cos(5.1985    + 77713.7715   * tau)
           + 1628.0     * cos(1.1739    + 5753.3849    * tau)
           + 1576.0     * cos(2.8469    + 7860.4194    * tau)
        let R = (R0 * 1e-8)
        return (L < 0 ? L + 2 * .pi : L, R)
    }

    // Mercury (Meeus Table 31.A truncated)
    private static func mercury(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 440250710.0
           + 40989415.0 * cos(1.4864338  + 26087.9031416 * tau)
           + 5046294.0  * cos(4.4778549  + 52175.8062831 * tau)
           + 855347.0   * cos(1.165203   + 78263.709425  * tau)
           + 165590.0   * cos(4.119692   + 104351.612566 * tau)
           + 534494.0   * cos(4.745799   + 415.552116    * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        var B = 217347.0  * cos(3.0 + 26087.9 * tau)
           + 44145.0   * cos(3.0 + 52175.8 * tau)
        B = B * 1e-8
        let R = (39528272.0 + 7834132.0 * cos(6.1923372 + 26087.903142 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    // Venus (Meeus Table 32.A truncated)
    private static func venus(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 317614667.0
           + 1353968.0  * cos(5.5931332  + 10213.2855462 * tau)
           + 89892.0    * cos(5.30650    + 20426.57109   * tau)
           + 5477.0     * cos(4.4163     + 7860.4194     * tau)
           + 3456.0     * cos(2.6996     + 11790.6291    * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        var B = 5923638.0 * cos(0.2670278 + 10213.2855462 * tau)
           + 40108.0   * cos(1.14737   + 20426.571092  * tau)
        B = B * 1e-8
        let R = (72334821.0 + 489824.0 * cos(4.021518 + 10213.285546 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    // Mars (Meeus Table 33.A truncated)
    private static func mars(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 1223514352.0
           + 40660012.0 * cos(6.0538088  + 3340.6124267  * tau)
           + 1108170.0  * cos(5.717756   + 6681.224853   * tau)
           + 91798.0    * cos(5.75478    + 10021.837371  * tau)
           + 1191.0     * cos(3.0263     + 2281.2305     * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        var B = 3197135.0 * cos(3.7683204 + 3340.6124267 * tau)
           + 298033.0  * cos(4.10677   + 6681.224853  * tau)
        B = B * 1e-8
        let R = (152699551.0 + 14184953.0 * cos(3.47971284 + 3340.6124267 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    // Jupiter (Meeus Table 34.A truncated)
    private static func jupiter(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 599471033.0
           + 52993480.0 * cos(0.2467248  + 529.6909651   * tau)
           + 1834243.0  * cos(4.846420   + 1059.381930   * tau)
           + 966110.0   * cos(1.667773   + 632.783739    * tau)
           + 245294.0   * cos(3.907196   + 522.577418    * tau)
           + 216275.0   * cos(0.346029   + 536.804512    * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        var B = 2278192.0 * cos(4.1788839 + 529.6909651 * tau)
           + 67799.0   * cos(3.559474  + 1059.381930  * tau)
        B = B * 1e-8
        let R = (520887429.0 + 25209327.0 * cos(3.49108289 + 529.6909651 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    // Saturn (Meeus Table 35.A truncated)
    private static func saturn(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 874016757.0
           + 21413299.0 * cos(3.2411768  + 213.2990954   * tau)
           + 1414024.0  * cos(4.582039   + 7.113547      * tau)
           + 773869.0   * cos(3.476461   + 426.598191    * tau)
           + 526646.0   * cos(2.217093   + 206.185548    * tau)
           + 435916.0   * cos(6.009941   + 220.412642    * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        var B = 4330678.0 * cos(3.6028443 + 213.2990954 * tau)
           + 240348.0  * cos(2.852385  + 426.598191   * tau)
        B = B * 1e-8
        let R = (955758136.0 + 52921382.0 * cos(2.39226220 + 213.2990954 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    // Uranus (Meeus Table 36.A truncated)
    private static func uranus(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 548129294.0
           + 7502543.0  * cos(6.1580358  + 74.7815986    * tau)
           + 511559.0   * cos(2.300041   + 149.563197    * tau)
           + 58427.0    * cos(2.28900    + 224.344672    * tau)
           + 45275.0    * cos(3.31510    + 38.133036     * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        var B = 1346277.0 * cos(2.6187781 + 74.7815986 * tau)
           + 62341.0   * cos(5.081806  + 149.563197  * tau)
        B = B * 1e-8
        let R = (1922879639.0 + 88784984.0 * cos(5.60737913 + 74.7815986 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    // Neptune (Meeus Table 37.A truncated)
    private static func neptune(_ T: Double) -> (L: Double, B: Double, R: Double) {
        let tau = T / 10.0
        var L = 531188633.0
           + 3606985.0  * cos(4.4400216  + 38.1330356    * tau)
           + 253332.0   * cos(5.782312   + 76.266071    * tau)
           + 9139.0     * cos(6.06183    + 1021.248894  * tau)
        L = (L * 1e-8).truncatingRemainder(dividingBy: 2 * .pi)
        var B = 3088622.0 * cos(1.4415852 + 38.1330356 * tau)
           + 27050.0   * cos(5.433864  + 76.266071   * tau)
        B = B * 1e-8
        let R = (3007013205.0 + 27062259.0 * cos(5.24270 + 38.1330356 * tau)) * 1e-8
        return (L < 0 ? L + 2 * .pi : L, B, R)
    }

    // Public: all 8 planets as (name, equatorial unit vector, base mag)
    static func allVectors(for date: Date, siderealOffset: Angle) -> [(planet: EPlanet, vec: SIMD3<Double>, ra: Double, dec: Double)] {
        let T = EPrecession.julianCenturies(from: date)
        let (eLon, eR) = earth(T)
        let eB = 0.0
        let planetData: [(EPlanet, (Double, Double, Double))] = [
            (EPlanet(name: "Mercury", color: .gray,                    baseMagnitude: -0.5), mercury(T)),
            (EPlanet(name: "Venus",   color: Color(red:1,green:0.97,blue:0.85), baseMagnitude: -4.0), venus(T)),
            (EPlanet(name: "Mars",    color: Color(red:1,green:0.35,blue:0.2),  baseMagnitude: -2.0), mars(T)),
            (EPlanet(name: "Jupiter", color: Color(red:1,green:0.87,blue:0.7),  baseMagnitude: -2.5), jupiter(T)),
            (EPlanet(name: "Saturn",  color: Color(red:0.95,green:0.87,blue:0.6), baseMagnitude:  0.7), saturn(T)),
            (EPlanet(name: "Uranus",  color: Color(red:0.6,green:0.9,blue:0.95), baseMagnitude:  5.7), uranus(T)),
            (EPlanet(name: "Neptune", color: Color(red:0.4,green:0.55,blue:1.0), baseMagnitude:  8.0), neptune(T)),
        ]
        var result: [(EPlanet, SIMD3<Double>, Double, Double)] = []
        for (planet, (pL, pB, pR)) in planetData {
            let (gL, gB) = geocentric(Lp: pL, Bp: pB, Rp: pR, Ls: eLon, Rs: eR)
            let (vec, ra, dec) = toVector(L: gL, B: gB, siderealOffset: siderealOffset)
            result.append((planet, vec, ra, dec))
        }
        return result
    }
}

// MARK: - Layer

struct EPlanetsLayer: EGridLayer {

    func draw(in dc: inout EGraphicContext) {
        let pairs = EPlanetPosition.allVectors(
            for: dc.state.observationDate,
            siderealOffset: dc.state.precessedSiderealOffset
        )
        for (planet, vec, ra, dec) in pairs {
            let raH = ra / 15.0
            print(String(format: "%-8@  RA: %6.2fh  Dec: %+7.2fdeg", planet.name as CVarArg, raH, dec))
            guard let projected = EProjection.project(
                vec,
                origin: dc.state.nsProjection.origin,
                plane: dc.state.nsProjection.plane
            ) else { continue }
            let sc = dc.toScreen(projected)
            guard dc.onScreen(sc, margin: 30) else { continue }
            // Dot radius from magnitude: brighter = bigger
            let r = CGFloat(max(1.5, (5.0 - planet.baseMagnitude) * 0.55))/2
            let glowR = r * 3.0
            // Glow
            dc.ctx.fill(
                Path(ellipseIn: CGRect(x: sc.x-glowR, y: sc.y-glowR, width: glowR*2, height: glowR*2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: planet.color.opacity(0.35), location: 0),
                        .init(color: planet.color.opacity(0),    location: 1)]),
                    center: sc, startRadius: 0, endRadius: glowR))
            // Core dot
            dc.ctx.fill(
                Path(ellipseIn: CGRect(x: sc.x-r, y: sc.y-r, width: r*2, height: r*2)),
                with: .color(planet.color))
            // Label
//            dc.ctx.draw(
//                Text(planet.name).font(.system(size: 8, weight: .medium)).foregroundStyle(planet.color.opacity(0.8)),
//                at: CGPoint(x: sc.x + r + 4, y: sc.y), anchor: .leading)
        }
    }
}

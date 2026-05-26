import Foundation
import simd

// Galactic coordinate system (IAU 1958, J2000).
// North Galactic Pole: RA 12h51m26.28s, Dec +27°07′42″
// Galactic centre:     RA 17h45m37s,    Dec −28°56′10″
enum EGalacticCoords {

    static let ngpRA:  Double = (12.0 + 51.0/60.0 + 26.28/3600.0) * 15.0 * .pi / 180.0
    static let ngpDec: Double = (27.0 +  7.0/60.0 + 42.00/3600.0)        * .pi / 180.0
    static let gcRA:   Double = (17.0 + 45.0/60.0 + 37.0/3600.0) * 15.0 * .pi / 180.0
    static let gcDec:  Double = -(28.0 + 56.0/60.0 + 10.0/3600.0)        * .pi / 180.0

    // Galactic frame unit vectors in J2000 equatorial:
    // xHat → galactic centre, yHat → rotation direction, zHat → NGP.
    static let zHat: SIMD3<Double> =
        SIMD3(cos(ngpDec) * cos(ngpRA), cos(ngpDec) * sin(ngpRA), sin(ngpDec))
    static let xHat: SIMD3<Double> =
        SIMD3(cos(gcDec)  * cos(gcRA),  cos(gcDec)  * sin(gcRA),  sin(gcDec))
    static let yHat: SIMD3<Double> = simd_cross(zHat, xHat)

    /// Galactic (l, b) in radians → J2000 equatorial unit vector.
    static func equatorialVector(l: Double, b: Double) -> SIMD3<Double> {
        let cosB = cos(b)
        return xHat * (cosB * cos(l))
             + yHat * (cosB * sin(l))
             + zHat * sin(b)
    }

    /// Brightness weight for a galactic-latitude strip: brightest on the
    /// plane (b = 0), fading to zero at `halfWidth` radians.
    static func bandOpacity(b: Double, halfWidth: Double = 0.35) -> Double {
        let t = abs(b) / halfWidth
        return max(0, 1.0 - t * t)
    }
}

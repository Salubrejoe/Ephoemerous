import simd
import SwiftUI
import LoreKit

// MARK: - SIMD3 (astronomy)
// Domain-coupled `SIMD3<Double>` helpers — celestial north / south
// unit vectors, the ecliptic-point factory, and the `sidereallyRotated`
// alias for LoreKit's generic Z-axis rotation. The pure 3D math
// (`baseVectors`, `rotateAbout{X,Y,Z}Axis`, `rotatedAboutZAxis`) lives
// in LoreKit's `SIMD3+Math.swift`.
extension SIMD3 where Scalar == Double {

    /// Celestial north pole — `+Z` on the unit sphere in equatorial
    /// coords. Named for astronomy readability; mathematically just
    /// `(0, 0, 1)`.
    static var north: SIMD3 {
        Angle.spherePoint(latitude: .degrees(90), longitude: .zero)
    }

    /// Celestial south pole — `-Z`. Same disclaimer as `.north`.
    static var south: SIMD3 {
        Angle.spherePoint(latitude: .degrees(-90), longitude: .zero)
    }

    /// Point on the ecliptic at ecliptic longitude λ (β = 0). Uses
    /// `AstroConstants.obliquity` to tilt the ecliptic out of the
    /// equator.
    static func eclipticPoint(lambda: Angle) -> SIMD3 {
        let obliquity = AstroConstants.obliquity
        return SIMD3(
            cos(lambda.radians),
            sin(lambda.radians) * cos(obliquity.radians),
            sin(lambda.radians) * sin(obliquity.radians)
        )
    }

    /// Sidereal rotation = rotation about the celestial Z axis by the
    /// local sidereal time. Domain-named alias for the generic
    /// `rotatedAboutZAxis(by:)` so call sites read in astronomy.
    func sidereallyRotated(by θ: Angle) -> SIMD3 {
        rotatedAboutZAxis(by: θ)
    }
}

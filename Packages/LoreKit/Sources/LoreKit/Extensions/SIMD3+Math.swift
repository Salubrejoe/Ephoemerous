import simd
import SwiftUI

// MARK: - SIMD3 3D math
// Pure 3D vector math on `SIMD3<Double>`: orthonormal basis tangent
// to a unit-sphere point, and rotations about each Cartesian axis
// (mutating + non-mutating). Domain-named aliases like
// `sidereallyRotated(by:)` belong in the consuming project — they
// just wrap one of these.
public extension SIMD3 where Scalar == Double {

    /// Orthonormal basis tangent to `self` on the unit sphere — the
    /// pair (e1, e2) span the plane perpendicular to `self`. Falls
    /// back to (1, 0, 0) when `self` is collinear with the Z axis
    /// (the cross-product degenerates there); the caller may want to
    /// detect that pole case before relying on basis continuity.
    func baseVectors() -> (e1: SIMD3, e2: SIMD3) {
        let zUp = SIMD3(0, 0, 1)
        var e1 = simd_cross(simd_cross(self, zUp), self)
        if simd_length_squared(e1) < 1e-10 { e1 = SIMD3(1, 0, 0) }
        e1 = simd_normalize(e1)
        let e2 = simd_normalize(simd_cross(self, e1))
        return (e1, e2)
    }

    // MARK: Mutating rotations

    mutating func rotateAboutXAxis(by θ: Angle) {
        let (c, s) = (cos(θ.radians), sin(θ.radians))
        self = SIMD3(
            self.x,
            self.y * c - self.z * s,
            self.y * s + self.z * c
        )
    }

    mutating func rotateAboutYAxis(by θ: Angle) {
        let (c, s) = (cos(θ.radians), sin(θ.radians))
        self = SIMD3(
            self.x * c + self.z * s,
            self.y,
            self.z * c - self.x * s
        )
    }

    mutating func rotateAboutZAxis(by θ: Angle) {
        let (c, s) = (cos(θ.radians), sin(θ.radians))
        self = SIMD3(
            self.x * c - self.y * s,
            self.x * s + self.y * c,
            self.z
        )
    }

    // MARK: Non-mutating

    /// Z-axis rotation, non-mutating. The frequent need: rotate a
    /// celestial vector by Local Sidereal Time without giving up
    /// `let` immutability at the call site.
    func rotatedAboutZAxis(by θ: Angle) -> SIMD3 {
        let (c, s) = (cos(θ.radians), sin(θ.radians))
        return SIMD3(
            self.x * c - self.y * s,
            self.x * s + self.y * c,
            self.z
        )
    }
}

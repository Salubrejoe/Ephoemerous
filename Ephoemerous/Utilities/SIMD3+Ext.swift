import simd
import SwiftUI


extension SIMD3 where Scalar == Double {
    
    static var north: SIMD3 {
        Angle.spherePoint(latitude: .degrees(90), longitude: .zero)
    }
    
    static var south: SIMD3 {
        Angle.spherePoint(latitude: .degrees(-90), longitude: .zero)
    }
    
    static func eclipticPoint(lambda: Angle) -> SIMD3 {
        let obliquity: Angle = .degrees(23.4393)
        return SIMD3(
            cos(lambda.radians),
            sin(lambda.radians) * cos(obliquity.radians),
            sin(lambda.radians) * sin(obliquity.radians)
        )
    }
    
    func baseVectors() -> (e1: SIMD3, e2: SIMD3) {
        let north = SIMD3.north
        var e1 = simd_cross(simd_cross(self, north), self)
        if simd_length_squared(e1) < 1e-10 { e1 = SIMD3(1, 0, 0) }
        e1 = simd_normalize(e1)
        let e2 = simd_normalize(simd_cross(self, e1))
        return (e1, e2)
    }
    
    mutating func rotateAboutXAxis(by θ: Angle) {
        self = SIMD3(
            self.x,
            self.y * cos(θ.radians) - self.z * sin(θ.radians),
            self.y * sin(θ.radians) + self.z * cos(θ.radians)
        )
    }

    mutating func rotateAboutYAxis(by θ: Angle) {
        self = SIMD3(
            self.x * cos(θ.radians) + self.z * sin(θ.radians),
            self.y,
            self.z * cos(θ.radians) - self.x * sin(θ.radians)
        )
    }
    
    mutating func rotateAboutZAxis(by θ: Angle) {
        self = SIMD3(
            self.x * cos(θ.radians) - self.y * sin(θ.radians),
            self.x * sin(θ.radians) + self.y * cos(θ.radians),
            self.z
        )
    }
    
    func sidereallyRotated(by θ: Angle) -> SIMD3 {
        SIMD3(
            self.x * cos(θ.radians) - self.y * sin(θ.radians),
            self.x * sin(θ.radians) + self.y * cos(θ.radians),
            self.z
        )
    }
}

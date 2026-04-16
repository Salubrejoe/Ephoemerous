import Foundation
import simd

enum EProjection {

    static func project(_ Q: SIMD3<Double>,
                        origin O: SIMD3<Double>,
                        plane  P: SIMD3<Double>) -> CGPoint? {
        let PdotO = simd_dot(P, O)
        let PdotQ = simd_dot(P, Q)
        let denom = PdotQ - PdotO
        guard abs(denom) > 1e-10 else { return nil }
        let t = (1.0 - PdotO) / denom
        guard t > 0 else { return nil }
        let intersection = O + t * (Q - O)
        let delta = intersection - P
        let (e1, e2) = tangentBasis(P)
        let u = simd_dot(delta, e1)
        let v = simd_dot(delta, e2)
        return CGPoint(x: v, y: u)
    }

    static func tangentBasis(_ P: SIMD3<Double>) -> (e1: SIMD3<Double>, e2: SIMD3<Double>) {
        let north = SIMD3<Double>(0, 0, 1)
        var e1 = simd_cross(simd_cross(P, north), P)
        if simd_length_squared(e1) < 1e-10 { e1 = SIMD3(1, 0, 0) }
        e1 = simd_normalize(e1)
        let e2 = simd_normalize(simd_cross(P, e1))
        return (e1, e2)
    }

    static func spherePoint(lat: Double, lon: Double) -> SIMD3<Double> {
        SIMD3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
    }

    static let obliquity: Double = 23.4393 * Double.pi / 180.0

    static func eclipticPoint(lambda: Double) -> SIMD3<Double> {
        SIMD3(cos(lambda), sin(lambda) * cos(obliquity), sin(lambda) * sin(obliquity))
    }

    static func sampleCurve(steps: Int = 180,
                            origin O: SIMD3<Double>,
                            plane  P: SIMD3<Double>,
                            point: (Double) -> SIMD3<Double>) -> [CGPoint?] {
        (0...steps).map { i in
            project(point(Double(i) / Double(steps)), origin: O, plane: P)
        }
    }
}


import SwiftUI
import simd


class ENSProjection {
    
    let origin         : SIMD3<Double>
    let plane          : SIMD3<Double>
    var siderealOffset : Angle
    
    init(siderealOffset: Angle) {
        self.origin = .north
        self.plane  = .south
        self.siderealOffset = siderealOffset
    }
    
    func makeEclipticPoints() -> [CGPoint?] {
        sampleEcliptic()
    }
    
    func makeParallelPoints(at decl: Angle) -> [CGPoint?] {
        sample { step in
            EPrecession.equatorialVector(ra: .radians(.twoPi * step), dec: decl)
                .sidereallyRotated(by: siderealOffset)
        }
    }
    
    func makeMeridianPoints(at ra: Angle) -> [CGPoint?] {
        sample { step in
            EPrecession.equatorialVector(
                ra: ra,
                dec: Angle.radians((step - 0.5) * .pi)
            )
                .sidereallyRotated(by: siderealOffset)
        }
        /*
         
        let (cSO, sSO) = (cos(siderealOffset.radians), sin(siderealOffset.radians))
        return sample { t in
            let v = makeMerEquatorialVector(t: t, h: h)
            return SIMD3<Double>(
                v.x * cSO - v.y * sSO,
                v.x * sSO + v.y * coSO,
                v.z
            )
        }
         */
    }
    
    /*
    func parallelLabelPoint(_ i: Int, dec: Angle) -> CGPoint? {
        let rot = makeParEquatorialVector(
            step: Double(i) * .pi * 0.5,
            decl: dec
        )
        return EProjection.project(rot, origin: origin, plane: plane)
    }
    */
    
    private func sample(steps: Int = 360,
                point: (Double) -> SIMD3<Double>) -> [CGPoint?] {
        (0...steps).map { i in
            EProjection.project(
                point(Double(i) / Double(steps)),
                origin: origin,
                plane: plane
            )
        }
    }
    
    private func sampleEcliptic(steps: Int = 360) -> [CGPoint?] {
        
        // Ecliptic -> β = 0.0
        (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let λ = t * 2 * .pi
            let β = 0.0
            let θ = siderealOffset.radians
            
            let ε = Angle.earthTilt.radians   // obliquity of the ecliptic
            let cb = cos(β), sb = sin(β)
            let cl = cos(λ), sl = sin(λ)
            let xe = cb * cl
            let ye = cb * sl
            let ze = sb
            let yq = ye * cos(ε) - ze * sin(ε)
            let zq = ye * sin(ε) + ze * cos(ε)
            let xq = xe
            let Q = SIMD3(
                xq * cos(θ) - yq * sin(θ),
                xq * sin(θ) + yq * cos(θ),
                zq
            )
            
            return EProjection.project(
                Q,
                origin: origin,
                plane: plane
            )
        }
    }
}

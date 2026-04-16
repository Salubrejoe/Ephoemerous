import SwiftUI
import simd


// MARK: - Celestial parallels (constant Dec, one every 20°)

struct EParallelsLayer: EGridLayer {
    
    func draw(in ctx: inout EGraphicContext) {
        let O = ctx.state.originVector
        let P = ctx.state.planeVector
        let θ = -ctx.state.siderealOffset
        let (c, s) = (cos(θ), sin(θ))
        
        
        // Celestial Equator
        let pts = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = ECalAndTransManager.equatorialVector(ra: ra, dec: 0)
            return SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
        }
        ctx.strokeCurve(pts, color: .primary.opacity(0.5), width: 4)
        
        let can = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = ECalAndTransManager.equatorialVector(ra: ra, dec: 0.41)
            return SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
        }
        ctx.strokeCurve(can, color: .primary.opacity(0.5), width: 1.5)
        
        let cap = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = ECalAndTransManager.equatorialVector(ra: ra, dec: -0.41)
            return SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
        }
        ctx.strokeCurve(cap, color: .primary.opacity(0.5), width: 1.5)
        
        let art = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = ECalAndTransManager.equatorialVector(ra: ra, dec: 1.15)
            return SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
        }
        ctx.strokeCurve(art, color: .primary.opacity(0.5), width: 1.5)
        
        let ant = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = ECalAndTransManager.equatorialVector(ra: ra, dec: -1.15)
            return SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
        }
        ctx.strokeCurve(ant, color: .primary.opacity(0.5), width: 1.5)
        
        for decDeg in stride(from: -80, through: 80, by: 20) {
            let dec   = Double(decDeg) * .pi / 180.0
            let label = decDeg == 0 ? "0°" : (decDeg > 0 ? "+\(decDeg)°" : "\(decDeg)°")
            
            // Full 360° sweep
            let pts = EProjection.sampleCurve(steps: 360, origin: O, plane: P) { t in
                let ra = t * 2 * .pi
                let v  = ECalAndTransManager.equatorialVector(ra: ra, dec: dec)
                return SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
            }
            
            ctx.strokeCurve(pts, color: .primary.opacity(0.5), width: 0.5)
            
            // Try 0h / 6h / 12h / 18h — use first position that lands on screen
            for i in 0..<4 {
                let ra  = Double(i) * .pi / 2.0
                let v   = ECalAndTransManager.equatorialVector(ra: ra, dec: dec)
                let rot = SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
                guard let proj = EProjection.project(rot, origin: O, plane: P) else { continue }
                let sc = ctx.toScreen(proj)
                guard ctx.onScreen(sc, margin: 20) else { continue }
                ctx.gridLabel(at: CGPoint(x: sc.x + 5, y: sc.y), text: label)
                break
            }
        }
    }
}

import SwiftUI
import simd


// MARK: - Celestial meridians (constant RA, one every 2 hours)

struct EMeridiansLayer: EGridLayer {
    
    let phaseCorrection = 0
    
    
    func makeEquatorialVector(at t: Double, atHour h: Int) -> Vector3D {
        let ra  = Double(h) * .pi / 12.0
        let dec = (t - 0.5) * .pi
        let v   = ECalAndTransManager.equatorialVector(ra: ra, dec: dec)
        return v
    }
    
    func draw(in ctx: inout EGraphicContext) {
        
        let state = ctx.state.gridState
        let (cosθ, sinθ) = (cos(state.θ), sin(state.θ))
        
        let vernalEquinox = EProjection.sampleCurve(
            origin : state.O,
            plane  : state.P
        ) { t in
            let v = makeEquatorialVector(at: t, atHour: phaseCorrection)
            return Vector3D(
                v.x * cosθ - v.y * sinθ,
                v.x * sinθ + v.y * cosθ,
                v.z
            )
        }
        ctx.strokeCurve(vernalEquinox, color: .purple, width: 0.5)
        
        let autumnalEquinox = EProjection.sampleCurve(
            origin : state.O,
            plane  : state.P
        ) { t in
            let v = makeEquatorialVector(at: t, atHour: phaseCorrection)
            
            return Vector3D(
                -v.x * cosθ - v.y * sinθ,
                -v.x * sinθ + v.y * cosθ,
                -v.z
            )
        }
        ctx.strokeCurve(autumnalEquinox, color: .purple.opacity(0.5), width: 0.5)
        
        let greenwich = EProjection.sampleCurve(
            origin : state.O,
            plane  : state.P
        ) { t in
            let v = makeEquatorialVector(at: t, atHour: 6)
            return Vector3D(
                v.x * cosθ - v.y * sinθ,
                v.x * sinθ + v.y * cosθ,
                v.z
            )
        }
        ctx.strokeCurve(greenwich, color: .blue, width: 0.5)
        
        let antiGreenwich = EProjection.sampleCurve(
            origin : state.O,
            plane  : state.P
        ) { t in
            let v = makeEquatorialVector(at: t, atHour: 18)
            
            return Vector3D(
                -v.x * cosθ - v.y * sinθ,
                 -v.x * sinθ + v.y * cosθ,
                 -v.z
            )
        }
        ctx.strokeCurve(antiGreenwich, color: .blue.opacity(0.5), width: 0.5)
        
        for h in stride(from: 0, to: 24, by: 2) {
            let ra = Double(h) * .pi / 12.0   // hours → radians
            
            // Sample pole-to-pole (t = 0 → dec = −π/2, t = 1 → dec = +π/2)
            let pts = EProjection.sampleCurve(
                origin : state.O,
                plane  : state.P
            ) { t in
                let dec = (t - 0.5) * .pi
                let v   = ECalAndTransManager.equatorialVector(ra: ra, dec: dec)
                return Vector3D(
                    v.x * cosθ - v.y * sinθ,
                    v.x * sinθ + v.y * cosθ,
                    v.z
                )
            }
            ctx.strokeCurve(pts, color: .primary.opacity(0.5), width: 0.2)
            
            // Label at the equator crossing (dec = 0)
            let eq = Vector3D(
                cos(ra) * cosθ - sin(ra) * sinθ,
                cos(ra) * sinθ + sin(ra) * cosθ,
                0.0
            )
            
            if let proj = EProjection.project(
                eq,
                origin : state.O,
                plane  : state.P
            ) {
                let sc = ctx.toScreen(proj)
                if ctx.onScreen(sc) {
                    ctx.gridLabel(
                        at: sc.applying(.init(translationX: 0, y: -8)),
                        text: "\(h-phaseCorrection)h"
                    )
                }
            }
        }
    }
}

import SwiftUI
import simd
import CoreLocation


struct EUserHorizonLayer: EGridLayer {
    let artist = EArtist.shared
    
    func draw(in ctx: inout EGraphicContext) {
        drawMeridians(in: &ctx)
        drawParallels(in: &ctx)
    }
    
    private func drawMeridians(in dc: inout EGraphicContext) {
        
        for ra in stride(from: 0, to: .twoPi, by: .pi / 8) {
            
            let pts = EProjection.sampleCurve(appState: dc.state) { t in
                EPrecession
                    .equatorialVector(
                        ra: .radians(ra),
                        dec: .radians((t - 0.5) * .pi)
                    )
                    .sidereallyRotated(by: dc.state.precessedSiderealOffset)
            }
            dc.strokeCurve(
                pts,
                color: artist.color,
                width: artist.width
//                width: ra == 0 ? artist.thickWidth : artist.width
            )
            
            /*
             // Label at the equator crossing (dec = 0)
             let eq = Vector3D(
             cos(ra) * cosθ - sin(ra) * sinθ,
             cos(ra) * sinθ + sin(ra) * cosθ,
             0.0
             )
             
             if let proj = EProjection.project(
             eq,
             origin : O,
             plane  : P
             ) {
             let sc = ctx.toScreen(proj)
             if ctx.onScreen(sc) {
             ctx.gridLabel(
             at: sc.applying(.init(translationX: 0, y: 0)),
             text: "\(h)h"
             )
             }
             }
             
             */
            
        }
    }
    
    private func drawParallels(in dc: inout EGraphicContext) {
        
        for decl in Angle.sunsets {
            let pts = EProjection.sampleCurve(appState: dc.state) { t in
                EPrecession
                    .equatorialVector(
                        ra: .radians(t * .twoPi),
                        dec: decl
                    )
                    .sidereallyRotated(by: dc.state.precessedSiderealOffset)
            }
            dc.strokeCurve(pts, color: artist.horColor, width: artist.horWidth)
        }
        
        let userLocPts = EProjection.sampleCurve(appState: dc.state) { t in
            EPrecession
                .equatorialVector(
                    ra: .radians(t * .twoPi),
                    dec: .zero
                )
                .sidereallyRotated(by: dc.state.precessedSiderealOffset)
        }
        dc.fillCurve(userLocPts, color: artist.horColor.opacity(0.5))
        
        
        
        /*
        for parallel in EKnownParallels.allCases {
            let pts = EProjection.sampleCurve(appState: dc.state) { t in
                EPrecession
                    .equatorialVector(
                        ra: .radians(t * .twoPi),
                        dec: parallel.declination
                    )
                    .sidereallyRotated(by: dc.state.precessedSiderealOffset)
            }
            dc.strokeCurve(
                pts,
                color: artist.color,
                width: parallel == .equator ? artist.thickWidth : artist.width
            )
        }
         */
    }
}




/*
struct EParallelsLayer: EGridLayer {
    
    let color       : Color = .primary.opacity(0.3)
    let width       : CGFloat = 0.1
    let thickWidth  : CGFloat = 0.2
    
    func draw(in dc: inout EGraphicContext) {
        let O = dc.state.originVector
        let P = dc.state.planeVector
        let θ = dc.state.precessedSiderealOffset
        
        // Home
        let home = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = EPrecession.equatorialVector(
                ra: .radians(ra),
                dec: dc.state.dynOriginLat * .pi / 180
            )
            return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
        }
        dc.fillCurve(home, color: .indigo.opacity(0.5))
        
        // Celestial Equator
        let pts = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = EPrecession.equatorialVector(ra: ra, dec: 0)
            return SIMD3(
                v.x * cos(θ) - v.y * sin(θ),
                v.x * sin(θ) + v.y * cos(θ),
                v.z
            )
        }
        dc.strokeCurve(pts, color: color, width: thickWidth)
        
        let can = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = EPrecession.equatorialVector(ra: ra, dec: 0.41)
            return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
        }
        dc.strokeCurve(can, color: color, width: thickWidth)
        
        let cap = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = EPrecession.equatorialVector(ra: ra, dec: -0.41)
            return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
        }
        dc.strokeCurve(cap, color: color, width: thickWidth)
        
        let art = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = EPrecession.equatorialVector(ra: ra, dec: 1.15)
            return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
        }
        //        ctx.strokeCurve(art, color: color, width: thickWidth)
        
        let ant = EProjection.sampleCurve(
            steps: 360,
            origin: O,
            plane: P
        ) { t in
            let ra = t * 2 * .pi
            let v  = EPrecession.equatorialVector(ra: ra, dec: -1.15)
            return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
        }
        //        ctx.strokeCurve(cap, color: color, width: thickWidth)
        
        for decDeg in stride(from: -80, through: 80, by: 20) {
            let dec   = Double(decDeg) * .pi / 180.0
            let label = decDeg == 0 ? "0°" : (decDeg > 0 ? "+\(decDeg)°" : "\(decDeg)°")
            
            // Full 360° sweep
            let pts = EProjection.sampleCurve(steps: 360, origin: O, plane: P) { t in
                let ra = t * 2 * .pi
                let v  = EPrecession.equatorialVector(ra: ra, dec: dec)
                return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
            }
            
            dc.strokeCurve(pts, color: color, width: width)
            
            // Try 0h / 6h / 12h / 18h — use first position that lands on screen
            for i in 0..<4 {
                let ra  = Double(i) * .pi / 2.0
                let v   = EPrecession.equatorialVector(ra: ra, dec: dec)
                let rot = SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
                guard let proj = EProjection.project(rot, origin: O, plane: P) else { continue }
                let sc = dc.toScreen(proj)
                guard dc.onScreen(sc, margin: 20) else { continue }
                dc.gridLabel(at: CGPoint(x: sc.x + 5, y: sc.y), text: label)
                break
            }
        }
    }
}

*/




/*
 //        ctx.strokeCurve(vernalEquinox, color: .purple, width: 1)
 
 let autumnalEquinox = EProjection.sampleCurve(
 origin : O,
 plane  : P
 ) { t in
 let v = makeEquatorialVector(at: t, atHour: phaseCorrection)
 
 return Vector3D(
 -v.x * cosθ - v.y * sinθ,
 -v.x * sinθ + v.y * cosθ,
 -v.z
 )
 }
 ctx.strokeCurve(autumnalEquinox, color: artist.color, width: artist.width)
 
 let greenwich = EProjection.sampleCurve(
 origin : O,
 plane  : P
 ) { t in
 let v = makeEquatorialVector(at: t, atHour: 6)
 return Vector3D(
 v.x * cosθ - v.y * sinθ,
 v.x * sinθ + v.y * cosθ,
 v.z
 )
 }
 ctx.strokeCurve(greenwich, color: artist.color, width: artist.thickWidth)
 
 let antiGreenwich = EProjection.sampleCurve(
 origin : O,
 plane  : P
 ) { t in
 let v = makeEquatorialVector(at: t, atHour: 18)
 
 return Vector3D(
 -v.x * cosθ - v.y * sinθ,
 -v.x * sinθ + v.y * cosθ,
 -v.z
 )
 }
 ctx.strokeCurve(antiGreenwich, color: artist.color, width: artist.width)
 */


/*
 // Home
 let home = EProjection.sampleCurve(
 steps: 360,
 origin: O,
 plane: P
 ) { t in
 let ra = t * 2 * .pi
 let v  = EPrecession.equatorialVector(
 ra: .radians(ra),
 dec: dc.state.dynOriginLat * .pi / 180
 )
 return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
 }
 dc.fillCurve(home, color: .indigo.opacity(0.5))
 
 // Celestial Equator
 let pts = EProjection.sampleCurve(
 steps: 360,
 origin: O,
 plane: P
 ) { t in
 let ra = t * 2 * .pi
 let v  = EPrecession.equatorialVector(ra: ra, dec: 0)
 return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
 }
 dc.strokeCurve(pts, color: color, width: thickWidth)
 
 let can = EProjection.sampleCurve(
 steps: 360,
 origin: O,
 plane: P
 ) { t in
 let ra = t * 2 * .pi
 let v  = EPrecession.equatorialVector(ra: ra, dec: 0.41)
 return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
 }
 dc.strokeCurve(can, color: color, width: thickWidth)
 
 let cap = EProjection.sampleCurve(
 steps: 360,
 origin: O,
 plane: P
 ) { t in
 let ra = t * 2 * .pi
 let v  = EPrecession.equatorialVector(ra: ra, dec: -0.41)
 return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
 }
 dc.strokeCurve(cap, color: color, width: thickWidth)
 
 let art = EProjection.sampleCurve(
 steps: 360,
 origin: O,
 plane: P
 ) { t in
 let ra = t * 2 * .pi
 let v  = EPrecession.equatorialVector(ra: ra, dec: 1.15)
 return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
 }
 //        ctx.strokeCurve(art, color: color, width: thickWidth)
 
 let ant = EProjection.sampleCurve(
 steps: 360,
 origin: O,
 plane: P
 ) { t in
 let ra = t * 2 * .pi
 let v  = EPrecession.equatorialVector(ra: ra, dec: -1.15)
 return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
 }
 //        ctx.strokeCurve(cap, color: color, width: thickWidth)
 
 for decDeg in stride(from: -80, through: 80, by: 20) {
 let dec   = Double(decDeg) * .pi / 180.0
 let label = decDeg == 0 ? "0°" : (decDeg > 0 ? "+\(decDeg)°" : "\(decDeg)°")
 
 // Full 360° sweep
 let pts = EProjection.sampleCurve(steps: 360, origin: O, plane: P) { t in
 let ra = t * 2 * .pi
 let v  = EPrecession.equatorialVector(ra: ra, dec: dec)
 return SIMD3(v.x * cos(θ) - v.y * sin(θ), v.x * sin(θ) + v.y * cos(θ), v.z)
 }
 
 dc.strokeCurve(pts, color: color, width: width)
 
 */


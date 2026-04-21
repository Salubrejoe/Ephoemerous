import SwiftUI
import simd


struct ENSGlobeLayer: EGridLayer {
    let artist = EArtist.shared
    
    func draw(in ctx: inout EGraphicContext) {
        drawParallels(in: &ctx)
//        drawMeridians(in: &ctx)
    }
    
    private func drawParallels(in dc: inout EGraphicContext) {
        let proj = dc.state.nsProjection
        
        let equator  = proj.makeParallelPoints(at: EKnownParallels.equator.declination)
        let trCancer = proj.makeParallelPoints(at: EKnownParallels.trCancer.declination)
        let trCapr   = proj.makeParallelPoints(at: EKnownParallels.trCapr.declination)
        
        
        dc.strokeCurve(equator,
                       color: artist.color, width: artist.thickWidth)
        dc.strokeCurve(trCancer,
                       color: artist.color, width: artist.width)
        dc.strokeCurve(trCapr,
                       color: artist.color, width: artist.width)
        
        /*
        for decDeg in stride(from: -90, through: 90, by: 30) {
            let dec = Angle.degrees(Double(decDeg))
            
            let pts = proj.makeParallelPoints(at: dec)
            dc.strokeCurve(pts, color:artist.color, width: artist.width)
            
            /*
             // LABEL
             let label = decDeg == 0 ? "0°" : (decDeg > 0 ? "+\(decDeg)°" : "\(decDeg)°")
             
             for i in 0..<4 {
             guard let labelPoint = proj.parallelLabelPoint(i, dec: dec) else { continue }
             let sc = dc.toScreen(labelPoint)
             
             guard dc.onScreen(sc, margin: 20) else { continue }
             dc.gridLabel(at: CGPoint(x: sc.x + 5, y: sc.y), text: label)
             break
             }
             */
            
        }
         */
    }
    
    private func drawMeridians(in dc: inout EGraphicContext) {
        
//        for h in stride(from: 0, to: 24, by: 3) {
        for ra in stride(from: 0, to: .twoPi, by: .pi / 6) {
            
            let pts = dc.state.nsProjection.makeMeridianPoints(at: .radians(ra))
            dc.strokeCurve(
                pts,
                color: artist.color,
                width: artist.width
//                width: ra == 0 ? artist.thickWidth : artist.width
            )
            
            /*
             // LABEL
            let ra = Double(h) * .pi / 12.0
            let θ = proj.siderealOffset.radians
            
            let eq = SIMD3(
                (cos(ra) * cos(θ) - sin(ra) * sin(θ)),
                (cos(ra) * sin(θ) + sin(ra) * cos(θ)),
                0.41
            )
            
            // Label at the equator crossing (dec = 0)
            if let point = EProjection.project(
                eq,
                origin : proj.origin,
                plane  : proj.plane
            ) {
                let sc = dc.toScreen(point)
                if dc.onScreen(sc) {
                    dc.gridLabel(
                        at: sc.applying(.init(translationX: 0, y: 0)),
                        text: "\(h)"
                    )
                }
            }
             */
        }
    }
}


/* OLD MERIDIANS
 
 let vernalEquinox = EProjection.sampleNorthSouthProjection { t in
 let v = makeMerEquatorialVector(at: t)
 return Vector3D(
 v.x * cosθ - v.y * sinθ,
 v.x * sinθ + v.y * cosθ,
 v.z
 )
 }
 ctx.strokeCurve(vernalEquinox, color: .pink, width: 1)
 
 let autumnalEquinox = EProjection.sampleNorthSouthProjection { t in
 let v = makeMerEquatorialVector(at: t)
 return Vector3D(
 -v.x * cosθ - v.y * sinθ,
 -v.x * sinθ + v.y * cosθ,
 -v.z
 )
 }
 ctx.strokeCurve(autumnalEquinox, color: color, width: width)
 //        ctx.strokeCurve(autumnalEquinox, color: .pink, width: 0.5)
 
 let greenwich = EProjection.sampleNorthSouthProjection { t in
 let v = makeMerEquatorialVector(at: t, phaseCorrection: 6)
 //            return Vector3D(v.x, v.y,v.z)
 return Vector3D(
 v.x * cosθ - v.y * sinθ,
 v.x * sinθ + v.y * cosθ,
 v.z
 )
 }
 ctx.strokeCurve(greenwich, color: color, width: width)
 ctx.strokeCurve(greenwich, color: .brown, width: 1)
 
 let antiGreenwich = EProjection.sampleNorthSouthProjection { t in
 let v = makeMerEquatorialVector(at: t, phaseCorrection: 18)
 //            return Vector3D(-v.x, v.y,-v.z)
 return Vector3D(
 -v.x * cosθ - v.y * sinθ,
 -v.x * sinθ + v.y * cosθ,
 -v.z
 )
 }
 ctx.strokeCurve(antiGreenwich, color: color, width: width)
 ctx.strokeCurve(antiGreenwich, color: .brown, width: 0.5)
 */

/*
 
 */

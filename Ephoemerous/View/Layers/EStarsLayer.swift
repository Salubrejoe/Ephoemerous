import SwiftUI
import CoreLocation
import simd


// MARK: - Angle: hour-angle initialiser (used by EPHStar)

extension Angle {
    init(hours h: Double, minutes m: Double = 0, seconds s: Double = 0) {
        self = .degrees((h + m / 60.0 + s / 3_600.0) * 15.0)
    }
}


// MARK: - Stars layer

struct EStarsLayer: EGridLayer {

    private static let stars: [EStar] =
    StarDatabase.shared.workableStars
        .filter {
            ($0.magnitude < 4.5) &&
            ($0.constellation.isCool) 
        }

    func draw(in dc: inout EGraphicContext) {
        let O = dc.state.originVector
        let P = dc.state.planeVector

        // Zenith in the sidereal-rotated frame.
        // sidereallyRotated applies R(−GMST); rotating observerZenith = spherePoint(lat, LST)
        // by −GMST yields spherePoint(lat, lon_geographic) — GMST cancels.
        let latRad = dc.state.location.coordinate.latitude  * .pi / 180
        let lonRad = dc.state.location.coordinate.longitude * .pi / 180
        let zenith = EProjection.spherePoint(lat: latRad, lon: lonRad)

        var count = 0
        
        for star in Self.stars {
            let ra  = star.rightAscension.radians
            let dec = star.declination.radians

            let (pRA, pDec) = ECalAndTransManager.precess(
                ra: ra, dec: dec, to: dc.state.observationDate
            )
            let Q = dc.sidereallyRotated(
                ECalAndTransManager.equatorialVector(ra: pRA, dec: pDec)
            )

            // Only draw stars above the observer's horizon
//            guard simd_dot(Q, zenith) > 0 else {
//                print("simd_dot(Q, zenith) < 0")
//                continue }

            guard let proj = EProjection.project(Q, origin: O, plane: P) else {
                print("EProjection.project(Q, origin: O, plane: P) == nil")
                continue
            }
            
            let sc = dc.toScreen(proj)
            guard sc.x > -20, sc.x < dc.size.width  + 20,
                  sc.y > -20, sc.y < dc.size.height + 20 else {
                continue
            }

            let r = max(0.6, (6.0 - star.magnitude) * 0.85)
            count += 1
            dc.fillDot(at: sc, radius: r, color: star.spectralClass.color)
        }
        print("\(count)")
    }
}

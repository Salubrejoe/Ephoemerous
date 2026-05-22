import SwiftUI
import simd

struct SunLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame
    private static var lastLoggedDate: Date = .distantPast

    func draw(in dc: inout EGraphicContext) {
        let date   = dc.renderedObservationDate
        let lambda = ESunPosition.eclipticLongitude(for: date)
        let (sunRA, sunDec) = ESunPosition.equatorialCoords(lambda: lambda)

        if mode == .northSouth, abs(date.timeIntervalSince(Self.lastLoggedDate)) > 0.5 {
            Self.lastLoggedDate = date
            logPipeline(date: date, lambda: lambda, ra: sunRA, dec: sunDec,
                        siderealOffset: dc.localSiderealOffset)
        }

        let th = dc.localSiderealOffset.radians
        let (c, s) = (cos(th), sin(th))
        
        
    // *
        let eq = SIMD3<Double>.eclipticPoint(lambda: lambda)
        let Q = SIMD3(eq.x * c - eq.y * s, eq.x * s + eq.y * c, eq.z)

        guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint, mode: mode) else { return }
        let sc = dc.toScreen(proj)
        let pos = sc; let state = dc.state
        DispatchQueue.main.async { state.sunScreenPosition = pos }

        artist.drawSun(at: sc, in: &dc)
    }

    private func logPipeline(date: Date, lambda: Angle, ra: Angle, dec: Angle, siderealOffset: Angle) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        ELogger.sun("Sun @ \(iso.string(from: date))")
        ELogger.sun("  lambda: \(String(format: "%.4f", lambda.degrees)) deg")
        ELogger.sun("  RA:     \(String(format: "%.4f", ra.degrees)) deg")
        ELogger.sun("  Dec:    \(String(format: "%.4f", dec.degrees)) deg")
        ELogger.sun("  GMST:   \(String(format: "%.4f", siderealOffset.degrees)) deg")
    }
}


// * OLD TRANSFORM
/*
 // TODO: Fix - both branches of this ternary are identical; the userLocation mode likely needs a different transform
 //        let eq = mode == .northSouth
 //            ? SIMD3<Double>.eclipticPoint(lambda: lambda)
 //            : SIMD3<Double>.eclipticPoint(lambda: lambda)
 */

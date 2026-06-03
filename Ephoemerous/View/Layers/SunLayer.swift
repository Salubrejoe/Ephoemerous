import SwiftUI
import simd

struct SunLayer: EGridLayer {
    private static var lastLoggedDate: Date = .distantPast

    func draw(in dc: inout EGraphicContext) {
        let date   = dc.renderedObservationDate
        let lambda = ESunPosition.eclipticLongitude(for: date)
        let (sunRA, sunDec) = ESunPosition.equatorialCoords(lambda: lambda)

        // Throttled debug log — 0.5 s spacing keeps it useful without
        // burning frame time. (The old gate to clock-mode is gone
        // along with the rest of the appMode plumbing.)
        if abs(date.timeIntervalSince(Self.lastLoggedDate)) > 0.5 {
            Self.lastLoggedDate = date
            logPipeline(date: date, lambda: lambda, ra: sunRA, dec: sunDec,
                        siderealOffset: dc.localSiderealOffset)
        }

        let th = dc.localSiderealOffset.radians
        let (c, s) = (cos(th), sin(th))

        let eq = SIMD3<Double>.eclipticPoint(lambda: lambda)
        let Q  = SIMD3(eq.x * c - eq.y * s, eq.x * s + eq.y * c, eq.z)

        guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { return }
        let sc = dc.toScreen(proj)
        let pos = sc; let state = dc.state
        // Equality-guard: at 10–120 Hz this layer would otherwise
        // republish a byte-identical CGPoint every frame and trigger
        // `ObjectsTrackingOverlay.body` invalidation for nothing.
        DispatchQueue.main.async {
            if state.sunScreenPosition != pos { state.sunScreenPosition = pos }
        }

        // Apple-Maps-style POI badge marks the sun.
        artist.drawPOILabel(
            at:        sc,
            glyph:     .sfSymbol("sun.max.fill"),
            text:      Strings.Bodies.sun,
            category:  .sun,
            promotion: dc.poiPromotion(forObjectID: ESkyObject.sun.id),
            in:        &dc
        )
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

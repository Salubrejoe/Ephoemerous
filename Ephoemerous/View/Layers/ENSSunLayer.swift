import SwiftUI
import simd

/// Diagnostic layer: draws a marker on the Sun and logs the full
/// coordinate pipeline to the console every time `observationDate` changes.
///
/// Compare logged RA/Dec against JPL Horizons or the Astronomical Almanac.
/// Accuracy: ~0.01° (Meeus low-precision solar formula).
///
/// Add to ECanvasView.layers to activate.
struct ENSSunLayer: EGridLayer {

    // MARK: - State tracking

    private static var lastLoggedDate: Date = .distantPast

    // MARK: - Draw

    func draw(in dc: inout EGraphicContext) {
        let date   = dc.state.renderedObservationDate
        let lambda = Self.sunEclipticLongitude(for: date)
        let (sunRA, sunDec) = Self.equatorialCoords(lambda: lambda)

        // ── Log on date change ──
        if abs(date.timeIntervalSince(Self.lastLoggedDate)) > 0.5 {
            Self.lastLoggedDate = date
            logPipeline(date: date, lambda: lambda, ra: sunRA, dec: sunDec,
                        siderealOffset: dc.state.precessedSiderealOffset)
        }

        // ── Project ──
        let θ = dc.state.precessedSiderealOffset.radians
        let (c, s) = (cos(θ), sin(θ))
        // eclipticPoint already converts ecliptic → equatorial (rotates by ε about X)
        let eq = SIMD3.eclipticPoint(lambda: lambda)
        let Q  = SIMD3(eq.x * c - eq.y * s,
                       eq.x * s + eq.y * c,
                       eq.z)

        guard let proj = EProjection.project(Q,
                                             appState: dc.state,
                                             mode: .northSouth) else { return }
        let sc = dc.toScreen(proj)
        let pos = sc; let state = dc.state; DispatchQueue.main.async { state.sunScreenPosition = pos }

        // ── Draw ──
        drawSunSymbol(at: sc, in: &dc)
    }

    // MARK: - Sun symbol

    private func drawSunSymbol(at sc: CGPoint, in dc: inout EGraphicContext) {
        let r = AstroConstants.sunDiscDiameter/2
        let disc = Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r,
                                          width: 2*r, height: 2*r))
        
        // Soft glow behind the star
        var glow = dc.ctx
        glow.addFilter(.blur(radius: r * 5.2))
        glow.fill(
            disc,
            with: .color(.yellow.opacity(1))
        )
        dc.ctx.fill(disc, with: .color(.yellow))
    }

    // MARK: - Solar position (Meeus §25, low-precision)

    /// Apparent ecliptic longitude of the Sun.
    static func sunEclipticLongitude(for date: Date) -> Angle {
        let T = EPrecession.julianCenturies(from: date)

        // Geometric mean longitude L₀ (deg)
        let L0 = (AstroConstants.sun_L0_base.degrees
                + AstroConstants.sun_L0_c1 * T
                + AstroConstants.sun_L0_c2 * T * T)
            .truncatingRemainder(dividingBy: 360)

        // Mean anomaly M (deg)
        let M = (AstroConstants.sun_M_base.degrees
               + AstroConstants.sun_M_c1 * T
               + AstroConstants.sun_M_c2 * T * T)
            .truncatingRemainder(dividingBy: 360)
        let Mrad = Angle.degrees(M).radians

        // Equation of centre (deg)
        let C = (AstroConstants.sun_C1_c0
               + AstroConstants.sun_C1_c1 * T
               + AstroConstants.sun_C1_c2 * T * T) * sin(Mrad)
              + (AstroConstants.sun_C2_c0
               + AstroConstants.sun_C2_c1 * T)     * sin(2 * Mrad)
              +  AstroConstants.sun_C3              * sin(3 * Mrad)

        // Sun's true longitude (deg)
        let sunLon = L0 + C

        // Apparent longitude — aberration & nutation correction (deg)
        let omega = (AstroConstants.sun_omega_base.degrees
                   + AstroConstants.sun_omega_c1 * T)
            .truncatingRemainder(dividingBy: 360)
        let omegaRad = Angle.degrees(omega).radians
        let lambda   = sunLon
                     + AstroConstants.sun_aberration
                     + AstroConstants.sun_nutation * sin(omegaRad)

        return .degrees(lambda)
    }

    /// RA and Dec of the Sun from its ecliptic longitude.
    static func equatorialCoords(lambda: Angle) -> (ra: Angle, dec: Angle) {
        let ε   = AstroConstants.obliquity.radians
        let ra  = atan2(cos(ε) * sin(lambda.radians), cos(lambda.radians))
        let dec = asin(sin(ε) * sin(lambda.radians))
        let returnedRA = Angle.radians(ra > 0 ? ra : ra + .twoPi)
        return (ra: returnedRA, dec: .radians(dec))
    }

    // MARK: - Logging

    private func logPipeline(date: Date, lambda: Angle,
                             ra: Angle, dec: Angle, siderealOffset: Angle) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        ELogger.sun("\n── Sun diagnostic @ \(iso.string(from: date)) ──")
        ELogger.sun("  [Ecliptic]")
        ELogger.sun("    λ (apparent)  \(String(format: "%.4f", lambda.degrees))°")
        ELogger.sun("  [Equatorial — computed]")
        ELogger.sun("    RA  \(raString(ra.degrees))  (\(String(format: "%.4f", ra.degrees))°)")
        ELogger.sun("    Dec \(decString(dec.degrees))  (\(String(format: "%.4f", dec.degrees))°)")
        let gmstH = siderealOffset.degrees / 15
        ELogger.sun("  [Sidereal]")
        ELogger.sun("    GMST  \(raString(siderealOffset.degrees))  (\(String(format: "%.4f", gmstH))h)")
        ELogger.sun("──────────────────────────────────────")
    }

    // MARK: - Formatters

    private func raString(_ deg: Double) -> String {
        var h = deg / 15
        if h < 0  { h += 24 }
        if h >= 24 { h -= 24 }
        let hh = Int(h)
        let mm = Int((h - Double(hh)) * 60)
        let ss = ((h - Double(hh)) * 60 - Double(mm)) * 60
        return String(format: "%02dh %02dm %05.2fs", hh, mm, ss)
    }

    private func decString(_ deg: Double) -> String {
        let sign = deg < 0 ? "−" : "+"
        let a    = abs(deg)
        let dd   = Int(a)
        let mm   = Int((a - Double(dd)) * 60)
        let ss   = ((a - Double(dd)) * 60 - Double(mm)) * 60
        return String(format: "%@%02d° %02d′ %05.2f″", sign, dd, mm, ss)
    }
}

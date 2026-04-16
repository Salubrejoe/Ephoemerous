import SwiftUI
import simd


/// Diagnostic layer: draws a marker on the Sun and logs the full
/// coordinate pipeline to the console every time `observationDate` changes.
///
/// Compare logged RA/Dec against JPL Horizons or the Astronomical Almanac.
/// Accuracy: ~0.01° (Meeus low-precision solar formula).
///
/// Add to ECanvasView.layers to activate.
struct ESunLayer: EGridLayer {

    // MARK: - State tracking

    private static var lastLoggedDate: Date = .distantPast

    // MARK: - Draw

    func draw(in dc: inout EGraphicContext) {

        let date = dc.state.observationDate

        let lambda = Self.sunEclipticLongitude(for: date)
        let (sunRA, sunDec) = Self.equatorialCoords(lambda: lambda)

        // ── Log on date change ──
        if abs(date.timeIntervalSince(Self.lastLoggedDate)) > 0.5 {
            Self.lastLoggedDate = date
            logPipeline(date: date, lambda: lambda, ra: sunRA, dec: sunDec,
                        siderealOffset: dc.state.siderealOffset)
        }

        // ── Project ──
        let θ = -dc.state.siderealOffset
        let (c, s) = (cos(θ), sin(θ))

        // eclipticPoint already converts ecliptic → equatorial (rotates by ε about X)
        let eq = EProjection.eclipticPoint(lambda: lambda)
        let Q  = SIMD3(eq.x * c - eq.y * s,
                       eq.x * s + eq.y * c,
                       eq.z)

        guard let proj = EProjection.project(Q,
                                             origin: dc.state.originVector,
                                             plane:  dc.state.planeVector) else { return }
        let sc = dc.toScreen(proj)

        // ── Draw ──
        drawSunSymbol(at: sc, in: &dc)
        dc.gridLabel(at: CGPoint(x: sc.x + 13, y: sc.y - 4), text: "Sun")
    }

    // MARK: - Sun symbol (filled circle + 8 short rays)

    private func drawSunSymbol(at sc: CGPoint, in dc: inout EGraphicContext) {
        // Core disc
        let disc = Path(ellipseIn: CGRect(x: sc.x - 6, y: sc.y - 6, width: 12, height: 12))
        dc.ctx.fill(disc, with: .color(.yellow))

        // Rays
        var rays = Path()
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            let inner: CGFloat = 8
            let outer: CGFloat = 13
            rays.move(to: CGPoint(x: sc.x + inner * cos(angle),
                                  y: sc.y + inner * sin(angle)))
            rays.addLine(to: CGPoint(x: sc.x + outer * cos(angle),
                                     y: sc.y + outer * sin(angle)))
        }
        dc.ctx.stroke(rays, with: .color(.yellow), lineWidth: 1.5)
    }

    // MARK: - Solar position (Meeus, low-precision)

    /// Apparent ecliptic longitude of the Sun in radians.
    static func sunEclipticLongitude(for date: Date) -> Double {
        let T = ECalAndTransManager.julianCenturies(from: date)

        // Geometric mean longitude (deg)
        let L0 = (280.46646 + 36000.76983 * T + 0.0003032 * T * T)
            .truncatingRemainder(dividingBy: 360)

        // Mean anomaly (deg)
        let M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T)
            .truncatingRemainder(dividingBy: 360)
        let Mrad = M * .pi / 180

        // Equation of centre (deg)
        let C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(Mrad)
              + (0.019993 - 0.000101 * T) * sin(2 * Mrad)
              +  0.000289                  * sin(3 * Mrad)

        // Sun's true longitude (deg)
        let sunLon = L0 + C

        // Apparent longitude — correct for aberration & nutation (deg)
        let omega    = (125.04 - 1934.136 * T).truncatingRemainder(dividingBy: 360)
        let omegaRad = omega * .pi / 180
        let lambda   = sunLon - 0.00569 - 0.00478 * sin(omegaRad)

        return lambda * .pi / 180   // radians
    }

    /// RA and Dec of the Sun in radians from its ecliptic longitude.
    static func equatorialCoords(lambda: Double) -> (ra: Double, dec: Double) {
        let ε = EProjection.obliquity
        let ra  = atan2(cos(ε) * sin(lambda), cos(lambda))
        let dec = asin(sin(ε) * sin(lambda))
        return (ra < 0 ? ra + 2 * .pi : ra, dec)
    }

    // MARK: - Logging

    private func logPipeline(date: Date, lambda: Double,
                             ra: Double, dec: Double, siderealOffset: Double) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        print("\n── Sun diagnostic @ \(iso.string(from: date)) ──")

        let lambdaDeg = lambda * 180 / .pi
        print("  [Ecliptic]")
        print("    λ (apparent)  \(String(format: "%.4f", lambdaDeg))°")

        print("  [Equatorial — computed]")
        print("    RA  \(raString(ra))  (\(String(format: "%.4f", ra * 180 / .pi))°)")
        print("    Dec \(decString(dec))  (\(String(format: "%.4f", dec * 180 / .pi))°)")

        let gmstH = (siderealOffset * 180 / .pi) / 15
        print("  [Sidereal]")
        print("    GMST  \(raString(siderealOffset))  (\(String(format: "%.4f", gmstH))h)")
        print("──────────────────────────────────────")
    }

    // MARK: - Formatters

    private func raString(_ rad: Double) -> String {
        var h = (rad * 180 / .pi) / 15
        if h < 0 { h += 24 }
        if h >= 24 { h -= 24 }
        let hh = Int(h)
        let mm = Int((h - Double(hh)) * 60)
        let ss = ((h - Double(hh)) * 60 - Double(mm)) * 60
        return String(format: "%02dh %02dm %05.2fs", hh, mm, ss)
    }

    private func decString(_ rad: Double) -> String {
        let deg  = rad * 180 / .pi
        let sign = deg < 0 ? "−" : "+"
        let a    = abs(deg)
        let dd   = Int(a)
        let mm   = Int((a - Double(dd)) * 60)
        let ss   = ((a - Double(dd)) * 60 - Double(mm)) * 60
        return String(format: "%@%02d° %02d′ %05.2f″", sign, dd, mm, ss)
    }
}

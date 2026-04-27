import SwiftUI
import simd

/// Diagnostic layer: draws a marker on Sirius and logs the full
/// coordinate pipeline to the console every time `observationDate` changes.
///
/// Compare logged values against:
///   Sirius J2000  RA  06h 45m 08.9173s  (+101.2872°)
///   Sirius J2000  Dec −16° 42′ 58.017″  (−16.7161°)
///
/// Add to ECanvasView.layers to activate.
struct ESiriusLayer: EGridLayer {

    // MARK: - Sirius J2000 (true catalogue values, ICRS/FK5)

    private static let catalogRA_h  = 6.0 + 45.0/60 + 8.9173/3600   // decimal hours
    private static let catalogDec_d = -(16.0 + 42.0/60 + 58.017/3600) // decimal degrees

    /// True J2000 RA in radians
    private static let trueRA:  Angle = .radians( catalogRA_h  * 15 * .pi / 180)
    /// True J2000 Dec in radians
    private static let trueDec: Angle = .radians(catalogDec_d * .pi / 180)

    // MARK: - State tracking (suppress duplicate log lines)

    private static var lastLoggedDate: Date = .distantPast

    // MARK: - Draw

    func draw(in dc: inout EGraphicContext) {

        let date = dc.state.observationDate

        // ── 1. Pull Sirius out of the model to expose what EStar stores ──
        let modelStar: EStar? = StarDatabase.shared.workableStars.min {
            abs($0.magnitude - (-1.46)) < abs($1.magnitude - (-1.46))
        }
        
        // ── 2. Log when date changes ──
        if abs(date.timeIntervalSince(Self.lastLoggedDate)) > 0.5 {
            Self.lastLoggedDate = date

            logPipeline(date: date, modelStar: modelStar, siderealOffset: dc.state.precessedSiderealOffset.degrees)
        }

        // ── 3. Draw using TRUE J2000 coordinates ──
        let (pRA, pDec) = EPrecession.precess(
            ra: Self.trueRA, dec: Self.trueDec, to: date
        )
        let θ = dc.state.precessedSiderealOffset.radians
        let (c, s) = (cos(θ), sin(θ))
        let v = EPrecession.equatorialVector(ra: pRA, dec: pDec)
        let Q = SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)

        guard let proj = EProjection.project(Q, origin: dc.state.originVector,
                                                plane: dc.state.planeVector) else { return }
        let sc = dc.toScreen(proj)

        // Ring
        let ring = Path(ellipseIn: CGRect(x: sc.x - 9, y: sc.y - 9, width: 18, height: 18))
        dc.ctx.stroke(ring, with: .color(.cyan), lineWidth: 1.5)

        // Label
        dc.gridLabel(at: CGPoint(x: sc.x + 12, y: sc.y - 4), text: "Sirius")
    }

    // MARK: - Logging

    private func logPipeline(date: Date, modelStar: EStar?, siderealOffset: Double) {

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        print("\n── Sirius diagnostic @ \(iso.string(from: date)) ──")

        // True catalogue
        print("  [Catalogue J2000]")
        print("    RA  \(raString(Self.trueRA.radians))  (\(degStr(Self.trueRA.degrees))°)")
        print("    Dec \(decString(Self.trueDec.radians))  (\(degStr(Self.trueDec.degrees))°)")

        // Precessed true values
        let (pRA, pDec) = EPrecession.precess(
            ra: Self.trueRA, dec: Self.trueDec, to: date
        )
        print("  [Precessed to date — true]")
        print("    RA  \(raString(pRA.radians))rad")
        print("    Dec \(decString(pDec.radians))rad")

        // What the model actually stores
        if let star = modelStar {
            let mRA  = star.rightAscension
            let mDec = star.declination
            print("  [EStar model (brightest star by magnitude)]")
            print("    name \(star.name)  magnitude \(star.magnitude)")
            print("    stored RA  \(raString(mRA.radians))  (\(degStr(mRA.degrees))°)")
            print("    stored Dec \(decString(mDec.radians))  (\(degStr(mDec.degrees))°)")

            let (mpRA, mpDec) = EPrecession.precess(ra: mRA, dec: mDec, to: date)
            print("  [Precessed to date — model]")
            print("    RA  \(raString(mpRA.radians))")
            print("    Dec \(decString(mpDec.radians))")
        }

        // Sidereal context
        let gmstH = (siderealOffset * 180 / .pi) / 15
        print("  [Sidereal]")
        print("    GMST  \(raString(siderealOffset))  (\(String(format: "%.4f", gmstH))h)")
        print("──────────────────────────────────────")
    }

    // MARK: - Formatters

    private func raString(_ rad: Double) -> String {
        var h = (rad * 180 / .pi) / 15
        if h < 0 { h += 24 }
        let hh = Int(h)
        let mm = Int((h - Double(hh)) * 60)
        let ss = ((h - Double(hh)) * 60 - Double(mm)) * 60
        return String(format: "%02dh %02dm %05.2fs", hh, mm, ss)
    }

    private func decString(_ rad: Double) -> String {
        let deg = rad * 180 / .pi
        let sign = deg < 0 ? "−" : "+"
        let a = abs(deg)
        let dd = Int(a)
        let mm = Int((a - Double(dd)) * 60)
        let ss = ((a - Double(dd)) * 60 - Double(mm)) * 60
        return String(format: "%@%02d° %02d′ %05.2f″", sign, dd, mm, ss)
    }

    private func degStr(_ d: Double) -> String { String(format: "%.4f", d) }
}

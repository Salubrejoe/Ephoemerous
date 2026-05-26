import SwiftUI
import simd

// MARK: - Angle math
// Pure angle constants + spherical-to-Cartesian + HMS/DMS string
// formatters. No astronomy specifics (those — twilight constants,
// AstroConstants-flavoured initializers, parallel rosters — stay
// in the consuming project alongside their domain types).
public extension Angle {

    static var pi:     Angle { .radians(.pi)         }
    static var twoPi:  Angle { .radians(.pi * 2)     }
    static var piHalf: Angle { .radians(.pi * 0.5)   }

    /// `Angle.pi(over: 3)` → π/3 radians. Reads as the natural English
    /// for fractional-π angles (π over 3, π over 6) without resorting
    /// to `.radians(.pi / 3)`. `divisor` of 0 produces an infinite
    /// angle — caller's responsibility.
    static func pi(over divisor: Double) -> Angle {
        .radians(.pi / divisor)
    }

    /// Spherical → Cartesian on the unit sphere. Latitude is the
    /// elevation above the equator (+Z is the north pole), longitude
    /// the azimuth around the Z axis.
    static func spherePoint(latitude lat: Angle, longitude lon: Angle) -> SIMD3<Double> {
        SIMD3(
            cos(lat.radians) * cos(lon.radians),
            cos(lat.radians) * sin(lon.radians),
            sin(lat.radians)
        )
    }

    // MARK: HMS / DMS string formatting
    // Hours-minutes-seconds and degrees-arcminutes-arcseconds — the
    // two notations astronomy and geodesy use to read angles aloud.
    // Pure formatting; works on any Angle.

    var hmsString: String {
        let t = radians * (12.0 / Double.pi) * 3600
        let h = Int(t / 3600)
        let m = Int(t.truncatingRemainder(dividingBy: 3600) / 60)
        let s = t.truncatingRemainder(dividingBy: 60)
        return String(format: "%02dh %02dm %05.2fs", h, m, s)
    }

    var dmsString: String {
        let d    = degrees
        let sign = d >= 0 ? "+" : "-"
        let a    = Swift.abs(d)
        let dd   = Int(a)
        let mm   = Int((a - Double(dd)) * 60)
        let ss   = (a - Double(dd) - Double(mm) / 60) * 3600
        return String(format: "%@%02d° %02d′ %05.2f″", sign, dd, mm, ss)
    }
}

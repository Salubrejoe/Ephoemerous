import Foundation
import simd

// MARK: - HorizonsEphemeris
// A geocentric track tabulated by JPL Horizons — one row a day of apparent
// RA/Dec of date and distance — for a craft too far out for SGP4 (JWST).
//
// Fetched GEOCENTRIC so the observer's position never leaves the phone;
// topocentric parallax (≈ 0.3° at L2 — the width of the Moon's disc) is put
// back here by subtracting the observer's own position, in `direction`.
nonisolated struct HorizonsEphemeris: Sendable {

    struct Row: Sendable {
        let date:  Date
        let unit:  SIMD3<Double>   // geocentric, equatorial of date
        let range: Double          // km
    }

    let rows: [Row]

    var coverage: ClosedRange<Date>? {
        guard let first = rows.first, let last = rows.last else { return nil }
        return first.date...last.date
    }

    // MARK: Query

    /// Unit topocentric direction at `date`, equatorial of date — the vector
    /// the sky camera projects — or nil outside the tabulated span.
    func direction(at date: Date, from observer: SatelliteSky.Observer) -> SIMD3<Double>? {
        guard let geo = geocentricKm(at: date) else { return nil }
        let site = SatelliteSky.rotateZ(observer.earthFixedKm, by: SatelliteSky.gmst(date))
        return simd_normalize(geo - site)
    }

    /// Distance from Earth's centre at `date`, km.
    func rangeKm(at date: Date) -> Double? {
        geocentricKm(at: date).map(simd_length)
    }

    /// Linear interpolation between the bracketing daily rows. JWST moves
    /// ~2° a day on a smooth halo orbit; the chord error across a day is a
    /// few arc-seconds.
    private func geocentricKm(at date: Date) -> SIMD3<Double>? {
        guard let coverage, coverage.contains(date) else { return nil }
        let i  = rows.lastIndex { $0.date <= date } ?? 0
        let a  = rows[i]
        guard i + 1 < rows.count else { return a.unit * a.range }
        let b  = rows[i + 1]
        let f  = date.timeIntervalSince(a.date) / b.date.timeIntervalSince(a.date)
        let va = a.unit * a.range
        let vb = b.unit * b.range
        return va + (vb - va) * f
    }

    // MARK: Request

    /// The Horizons query for a craft's geocentric daily track — a month
    /// back to a year ahead at one row a day, ~400 lines, ~30 KB. Shared by
    /// the app's tracker and the widget, so both ask exactly the same way.
    static func requestURL(horizonsID id: String, around date: Date) -> URL? {
        let day   = horizonsDay
        var parts = URLComponents(string: "https://ssd.jpl.nasa.gov/api/horizons.api")
        parts?.queryItems = [
            .init(name: "format",      value: "text"),
            .init(name: "COMMAND",     value: "'\(id)'"),
            .init(name: "EPHEM_TYPE",  value: "OBSERVER"),
            .init(name: "CENTER",      value: "'500@399'"),
            .init(name: "START_TIME",  value: "'\(day.string(from: date.addingTimeInterval(-30 * 86_400)))'"),
            .init(name: "STOP_TIME",   value: "'\(day.string(from: date.addingTimeInterval(365 * 86_400)))'"),
            .init(name: "STEP_SIZE",   value: "'1 d'"),
            .init(name: "QUANTITIES",  value: "'2,20'"),
            .init(name: "CSV_FORMAT",  value: "YES"),
            .init(name: "ANG_FORMAT",  value: "DEG"),
        ]
        return parts?.url
    }

    private static let horizonsDay: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: Parse

    /// Rows from a Horizons `format=text` observer table requested with
    /// `QUANTITIES='2,20'`, `CSV_FORMAT=YES`, `ANG_FORMAT=DEG`:
    ///   ` 2026-Sep-29 00:00, , ,    18.93386,    19.10778,  0.00857661514011,  0.0932031,`
    static func parse(_ text: String) -> HorizonsEphemeris? {
        guard let start = text.range(of: "$$SOE"),
              let end   = text.range(of: "$$EOE", range: start.upperBound..<text.endIndex)
        else { return nil }

        let deg = Double.pi / 180
        let au  = 149_597_870.7
        let rows: [Row] = text[start.upperBound..<end.lowerBound]
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let cols = line.split(separator: ",", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard cols.count >= 6,
                      let date  = rowFormatter.date(from: cols[0]),
                      let ra    = Double(cols[3]),
                      let dec   = Double(cols[4]),
                      let delta = Double(cols[5])
                else { return nil }
                let α = ra * deg, δ = dec * deg
                return Row(date:  date,
                           unit:  SIMD3(cos(δ) * cos(α), cos(δ) * sin(α), sin(δ)),
                           range: delta * au)
            }
        return rows.isEmpty ? nil : HorizonsEphemeris(rows: rows)
    }

    private static let rowFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MMM-dd HH:mm"
        return f
    }()
}

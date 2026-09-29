import Foundation
import simd

// MARK: - SpacecraftFacts
// Everything the spacecraft detail sheet says, worked out and worded here
// so the view only lays it out. All of it is "at the observation moment,
// from the observer" — the same frozen instant the sky is drawn for.
struct SpacecraftFacts {

    let craft:    Spacecraft
    let date:     Date
    let observer: SatelliteSky.Observer
    private let tracker = SpacecraftTracker.shared

    // MARK: Stats

    var stats: [DetailStat] {
        guard tracker.isTracked(craft, at: date) else {
            return [.init(label: String(localized: "Position"),
                          value: String(localized: "No orbit data for this date"))]
        }
        return craft.isInEarthOrbit ? orbitStats : deepSpaceStats
    }

    private var orbitStats: [DetailStat] {
        guard let orbit = tracker.orbits[craft],
              let state = try? orbit.state(at: date),
              let look  = tracker.look(of: craft, at: date, from: observer)
        else { return [] }
        let sun      = SatelliteSky.sunDirection(date)
        let sunlit   = SatelliteSky.isSunlit(state.position, sun: sun)
        let height   = simd_length(state.position) - SGP4.earthRadiusKm
        let speed    = simd_length(state.velocity)
        return [
            .init(label: String(localized: "Altitude"),  value: Self.altitudeText(look.altitude)),
            .init(label: String(localized: "Direction"), value: Self.directionText(look.azimuth)),
            .init(label: String(localized: "Distance"),  value: Self.kilometres(look.rangeKm)),
            .init(label: String(localized: "Height"),    value: Self.kilometres(height)),
            .init(label: String(localized: "Speed"),     value: String(localized: "\(speed, format: .number.precision(.fractionLength(1))) km/s")),
            .init(label: String(localized: "Light"),     value: sunlit ? String(localized: "Sunlit")
                                                                       : String(localized: "In Earth's shadow")),
            .init(label: String(localized: "Brightness"), value: brightnessText(look: look, sunlit: sunlit, sun: sun)),
            .init(label: String(localized: "Orbit data"), value: Self.ageText(since: orbit.elements.epoch)),
        ]
    }

    private var deepSpaceStats: [DetailStat] {
        guard let dir   = tracker.direction(of: craft, at: date, from: observer),
              let range = tracker.rangeKm(of: craft, at: date, from: observer)
        else { return [] }
        let sky = SatelliteSky.horizontal(of: dir, from: observer, date: date)
        return [
            .init(label: String(localized: "Altitude"),   value: Self.altitudeText(sky.altitude)),
            .init(label: String(localized: "Direction"),  value: Self.directionText(sky.azimuth)),
            .init(label: String(localized: "Distance"),   value: String(localized: "\(range / 1e6, format: .number.precision(.fractionLength(2))) million km")),
            .init(label: String(localized: "Brightness"), value: String(localized: "Mag 16 · telescope only")),
            .init(label: String(localized: "Position"),   value: String(localized: "JPL Horizons")),
        ]
    }

    private func brightnessText(look: SatelliteSky.Look, sunlit: Bool, sun: SIMD3<Double>) -> String {
        let dark = SatelliteSky.altitude(of: sun, from: observer, date: date)
                <= SatellitePassPredictor.darkSkySunAltitude
        guard look.altitude > 0, sunlit, dark else { return String(localized: "Not visible now") }
        let mag = SatelliteSky.magnitude(standard: craft.standardMagnitude, look: look, sun: sun)
        return String(localized: "Mag \(Self.magnitude(mag))")
    }

    // MARK: Passes

    /// The next few passes you could actually see, soonest first.
    var visiblePasses: [SatellitePass] {
        (tracker.passes[craft] ?? [])
            .filter { $0.isVisible && ($0.visibleEnd?.date ?? .distantPast) > date }
            .prefix(4)
            .map { $0 }
    }

    static func whenText(_ pass: SatellitePass) -> String {
        (pass.visibleStart ?? pass.rise).date
            .formatted(.dateTime.weekday(.abbreviated).day().hour().minute())
    }

    /// "4 min · 38° high · NW → SE · mag −2.1"
    static func summaryText(_ pass: SatellitePass) -> String {
        guard let start = pass.visibleStart, let end = pass.visibleEnd else { return "" }
        let minutes = max(1, Int((end.date.timeIntervalSince(start.date) / 60).rounded()))
        var parts   = [String(localized: "\(minutes) min"),
                       String(localized: "\(Int((pass.peak.altitude * 180 / .pi).rounded()))° high"),
                       "\(compassPoint(start.azimuth)) → \(compassPoint(end.azimuth))"]
        if let mag = pass.magnitude { parts.append(String(localized: "mag \(magnitude(mag))")) }
        return parts.joined(separator: " · ")
    }

    // MARK: Wording

    private static func altitudeText(_ altitude: Double) -> String {
        let deg = Int((altitude * 180 / .pi).rounded())
        return deg >= 0 ? String(localized: "\(deg)° above horizon")
                        : String(localized: "Below horizon")
    }

    private static func directionText(_ azimuth: Double) -> String {
        "\(compassPoint(azimuth)) · \(Int((azimuth * 180 / .pi).rounded()))°"
    }

    private static func kilometres(_ km: Double) -> String {
        String(localized: "\(km, format: .number.precision(.fractionLength(0))) km")
    }

    private static func magnitude(_ mag: Double) -> String {
        mag.formatted(.number.precision(.fractionLength(1)))
            .replacingOccurrences(of: "-", with: "−")
    }

    private static func ageText(since date: Date) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }

    private static let compassPoints = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                                        "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]

    static func compassPoint(_ azimuth: Double) -> String {
        let i = Int(((azimuth * 180 / .pi) / 22.5).rounded()) % 16
        return compassPoints[(i + 16) % 16]
    }
}

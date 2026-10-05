import Foundation
import Observation
import simd

// MARK: - SpacecraftTracker
// Keeps the ISS, Tiangong, Hubble and JWST where they belong, and says when
// the three low-orbit craft will next cross the observer's sky.
//
// Network: three tiny CelesTrak requests (one element set each — the endpoint
// takes a single CATNR) and one JPL Horizons table. Both are keyless, and
// neither is ever told where the user is: orbits are propagated and passes
// predicted on the phone, and JWST is fetched geocentric. Responses are
// cached on disk as they arrive, so the sky works offline from the last
// good fetch.
//
// Politeness: CelesTrak refits element sets a few times a day and asks
// clients not to poll faster than that; Horizons' JWST track is smooth
// enough that a weekly refresh of a year-long table is generous.
@Observable
final class SpacecraftTracker {

    static let shared = SpacecraftTracker()

    // MARK: Published

    private(set) var orbits:  [Spacecraft: SGP4]              = [:]
    private(set) var webb:    HorizonsEphemeris?              = nil
    private(set) var passes:  [Spacecraft: [SatellitePass]]   = [:]

    // MARK: Tuning ▼ TWEAK ▼

    /// Element sets older than this get refetched.
    static let orbitRefreshAge:     TimeInterval = 12 * 3_600
    /// The Horizons table gets refetched once a week.
    static let ephemerisRefreshAge: TimeInterval = 7 * 86_400
    /// SGP4 drifts by kilometres a day; past this distance from the element
    /// epoch a pin would lie about where the craft is, so it isn't drawn.
    static let orbitTrustSpan:      TimeInterval = 10 * 86_400
    /// Redraw interval for live spacecraft marks. The ISS covers ~0.07° a
    /// second, so 15 Hz reads as continuous motion at any zoom while
    /// costing a fraction of a full-rate redraw.
    static let liveFrameInterval:   TimeInterval = 1.0 / 15
    /// How far ahead pass predictions look.
    static let passHorizon:         TimeInterval = 5 * 86_400

    private var passKey: PassKey?
    private var isRefreshing = false

    private init() {
        loadCache()
    }

    // MARK: Positions

    /// Unit topocentric direction, equatorial of date — feed straight to
    /// `SkyCamera.screen(equatorial:)` — or nil when there's no trustworthy
    /// data for that moment.
    func direction(of craft: Spacecraft, at date: Date, from observer: SatelliteSky.Observer) -> SIMD3<Double>? {
        switch craft {
        case .jwst:
            return webb?.direction(at: date, from: observer)
        case .iss, .hubble, .tiangong:
            guard let orbit = trustedOrbit(craft, at: date),
                  let state = try? orbit.state(at: date)
            else { return nil }
            return SatelliteSky.look(at: state.position, from: observer, date: date).direction
        }
    }

    /// Full look (altitude, azimuth, range) for the Earth-orbit craft.
    func look(of craft: Spacecraft, at date: Date, from observer: SatelliteSky.Observer) -> SatelliteSky.Look? {
        guard let orbit = trustedOrbit(craft, at: date),
              let state = try? orbit.state(at: date)
        else { return nil }
        return SatelliteSky.look(at: state.position, from: observer, date: date)
    }

    /// Distance from the observer (Earth-orbit craft) or from Earth (JWST), km.
    func rangeKm(of craft: Spacecraft, at date: Date, from observer: SatelliteSky.Observer) -> Double? {
        craft == .jwst ? webb?.rangeKm(at: date) : look(of: craft, at: date, from: observer)?.rangeKm
    }

    /// Whether we hold data that covers `date` at all.
    func isTracked(_ craft: Spacecraft, at date: Date) -> Bool {
        craft == .jwst ? webb?.coverage?.contains(date) == true
                       : trustedOrbit(craft, at: date) != nil
    }

    private func trustedOrbit(_ craft: Spacecraft, at date: Date) -> SGP4? {
        guard let orbit = orbits[craft],
              abs(date.timeIntervalSince(orbit.elements.epoch)) < Self.orbitTrustSpan
        else { return nil }
        return orbit
    }

    // MARK: Passes

    /// The next visible pass of `craft` still to finish after `date`.
    func nextVisiblePass(of craft: Spacecraft, after date: Date) -> SatellitePass? {
        passes[craft]?.first { $0.isVisible && ($0.visibleEnd?.date ?? $0.set.date) > date }
    }

    /// Recomputes passes when the observer moves or the window has slid
    /// on by more than an hour. Runs off the main actor; ~5 ms per craft.
    func updatePasses(for observer: SatelliteSky.Observer, from date: Date) {
        let key = PassKey(observer: observer, start: date, orbitEpochs: orbits.mapValues(\.elements.epoch))
        guard passKey?.isEquivalent(to: key) != true else { return }
        passKey = key

        let orbits = self.orbits
        let span   = Self.passHorizon
        Task.detached(priority: .utility) {
            var result: [Spacecraft: [SatellitePass]] = [:]
            for (craft, orbit) in orbits {
                result[craft] = SatellitePassPredictor.passes(of:                orbit,
                                                              standardMagnitude: craft.standardMagnitude,
                                                              from:              observer,
                                                              start:             date,
                                                              span:              span)
            }
            let predicted = result
            await MainActor.run { self.passes = predicted }
        }
    }

    private struct PassKey {
        let observer:    SatelliteSky.Observer
        let start:       Date
        let orbitEpochs: [Spacecraft: Date]

        func isEquivalent(to other: PassKey) -> Bool {
            abs(observer.latitude  - other.observer.latitude)  < 1e-4
                && abs(observer.longitude - other.observer.longitude) < 1e-4
                && abs(start.timeIntervalSince(other.start)) < 3_600
                && orbitEpochs == other.orbitEpochs
        }
    }

    // MARK: Refresh

    /// Fetches whatever is stale. Safe to call on every foregrounding.
    func refreshIfStale() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        for craft in Spacecraft.allCases where craft.isInEarthOrbit {
            let file = Self.cacheURL(for: craft)
            guard Self.age(of: file) > Self.orbitRefreshAge,
                  let data = await Self.fetch(Self.celestrakURL(for: craft)),
                  let orbit = Self.decodeOrbit(data)
            else { continue }
            try? data.write(to: file, options: .atomic)
            orbits[craft] = orbit
        }

        let file = Self.cacheURL(for: .jwst)
        if Self.age(of: file) > Self.ephemerisRefreshAge,
           let data = await Self.fetch(Self.horizonsURL(for: .jwst, around: .now)),
           let text = String(data: data, encoding: .utf8),
           let table = HorizonsEphemeris.parse(text) {
            try? data.write(to: file, options: .atomic)
            webb = table
        }
    }

    private func loadCache() {
        for craft in Spacecraft.allCases where craft.isInEarthOrbit {
            if let data = try? Data(contentsOf: Self.cacheURL(for: craft)) {
                orbits[craft] = Self.decodeOrbit(data)
            }
        }
        if let data = try? Data(contentsOf: Self.cacheURL(for: .jwst)),
           let text = String(data: data, encoding: .utf8) {
            webb = HorizonsEphemeris.parse(text)
        }
    }

    // MARK: Endpoints

    private static func celestrakURL(for craft: Spacecraft) -> URL? {
        guard let id = craft.noradID else { return nil }
        return URL(string: "https://celestrak.org/NORAD/elements/gp.php?CATNR=\(id)&FORMAT=json")
    }

    private static func horizonsURL(for craft: Spacecraft, around date: Date) -> URL? {
        craft.horizonsID.flatMap { HorizonsEphemeris.requestURL(horizonsID: $0, around: date) }
    }

    private static func fetch(_ url: URL?) async -> Data? {
        guard let url else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }

    private static func decodeOrbit(_ data: Data) -> SGP4? {
        guard let elements = try? OrbitalElements.decoder.decode([OrbitalElements].self, from: data).first
        else { return nil }
        return try? SGP4(elements)
    }

    // MARK: Cache files

    private static let cacheDirectory: URL = {
        let dir = URL.cachesDirectory.appending(path: "Spacecraft", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func cacheURL(for craft: Spacecraft) -> URL {
        cacheDirectory.appending(path: craft.isInEarthOrbit ? "\(craft.rawValue).json" : "\(craft.rawValue).txt")
    }

    private static func age(of file: URL) -> TimeInterval {
        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return modified.map { -$0.timeIntervalSinceNow } ?? .infinity
    }
}

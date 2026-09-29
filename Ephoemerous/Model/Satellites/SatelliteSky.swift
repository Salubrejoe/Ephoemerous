import Foundation
import simd

// MARK: - SatelliteSky
// Where a propagated spacecraft appears from one spot on the ground.
//
// Everything is in the "of date" equatorial frame SGP4 hands back (TEME),
// so the topocentric direction it produces drops straight into
// `SkyCamera.screen(equatorial:)` like a precessed star does — the camera
// applies its own −GMST, exactly as it does for every other body.
//
// Self-contained on purpose (its own GMST and Sun, no shared caches): pass
// prediction propagates thousands of instants off the main thread, and the
// renderer's single-entry caches (`SunPosition`, `Precession`) are
// main-thread-only by contract.
nonisolated enum SatelliteSky {

    // MARK: Observer

    /// A geodetic spot on the WGS-84 ellipsoid (sea level — a few hundred
    /// metres of elevation moves a LEO satellite by well under a degree).
    struct Observer: Equatable, Sendable {
        let latitude:  Double   // rad, geodetic, north +
        let longitude: Double   // rad, east +

        init(latitude: Double, longitude: Double) {
            self.latitude  = latitude
            self.longitude = longitude
        }

        init(latitudeDegrees: Double, longitudeDegrees: Double) {
            self.init(latitude:  latitudeDegrees  * .pi / 180,
                      longitude: longitudeDegrees * .pi / 180)
        }

        /// Earth-fixed position, km.
        var earthFixedKm: SIMD3<Double> {
            let a  = 6_378.137
            let f  = 1 / 298.257_223_563
            let e2 = f * (2 - f)
            let sφ = sin(latitude), cφ = cos(latitude)
            let N  = a / (1 - e2 * sφ * sφ).squareRoot()
            return SIMD3(N * cφ * cos(longitude),
                         N * cφ * sin(longitude),
                         N * (1 - e2) * sφ)
        }

        /// Local east / north / up unit vectors, earth-fixed.
        var enuBasis: (east: SIMD3<Double>, north: SIMD3<Double>, up: SIMD3<Double>) {
            let sφ = sin(latitude),  cφ = cos(latitude)
            let sλ = sin(longitude), cλ = cos(longitude)
            return (SIMD3(-sλ, cλ, 0),
                    SIMD3(-sφ * cλ, -sφ * sλ, cφ),
                    SIMD3( cφ * cλ,  cφ * sλ, sφ))
        }
    }

    // MARK: Look angles

    struct Look: Sendable {
        let azimuth:   Double          // rad, from north through east
        let altitude:  Double          // rad
        let rangeKm:   Double
        /// Unit topocentric direction, equatorial of date — the vector the
        /// sky camera projects.
        let direction: SIMD3<Double>
    }

    /// Topocentric look from `observer` to a TEME position at `date`.
    static func look(at positionKm: SIMD3<Double>, from observer: Observer, date: Date) -> Look {
        let θ         = gmst(date)
        let site      = rotateZ(observer.earthFixedKm, by: θ)
        let rho       = positionKm - site
        let range     = simd_length(rho)
        let local     = rotateZ(rho, by: -θ)
        let basis     = observer.enuBasis
        let east      = simd_dot(local, basis.east)
        let north     = simd_dot(local, basis.north)
        let up        = simd_dot(local, basis.up)
        var azimuth   = atan2(east, north)
        if azimuth < 0 { azimuth += 2 * .pi }
        return Look(azimuth:   azimuth,
                    altitude:  asin(up / range),
                    rangeKm:   range,
                    direction: rho / range)
    }

    /// Altitude of a direction (Sun, JWST) for the observer.
    static func altitude(of direction: SIMD3<Double>, from observer: Observer, date: Date) -> Double {
        horizontal(of: direction, from: observer, date: date).altitude
    }

    /// Azimuth (from north through east) and altitude of a direction, rad.
    static func horizontal(of direction: SIMD3<Double>, from observer: Observer,
                           date: Date) -> (azimuth: Double, altitude: Double) {
        let local = simd_normalize(rotateZ(direction, by: -gmst(date)))
        let basis = observer.enuBasis
        var az    = atan2(simd_dot(local, basis.east), simd_dot(local, basis.north))
        if az < 0 { az += 2 * .pi }
        return (az, asin(max(-1, min(1, simd_dot(local, basis.up)))))
    }

    // MARK: Illumination

    /// True when the spacecraft is out of Earth's shadow — a cylindrical
    /// umbra is plenty for "can you see it glint": the penumbra of a LEO
    /// pass lasts a few seconds.
    static func isSunlit(_ positionKm: SIMD3<Double>, sun: SIMD3<Double>) -> Bool {
        let along = simd_dot(positionKm, sun)
        guard along < 0 else { return true }
        return simd_length(positionKm - along * sun) > SGP4.earthRadiusKm
    }

    /// Estimated visual magnitude from a standard magnitude (1000 km range,
    /// half-lit — the Heavens-Above / McCants convention), with a diffuse-
    /// sphere phase law. Good to about half a magnitude; ISS flares and
    /// solar-panel attitude aren't modelled.
    static func magnitude(standard: Double, look: Look, sun: SIMD3<Double>) -> Double {
        let phase    = acos(max(-1, min(1, simd_dot(sun, -look.direction))))
        let fraction = (sin(phase) + (.pi - phase) * cos(phase)) / .pi
        let halfLit  = 1 / Double.pi
        return standard
             + 5 * log10(look.rangeKm / 1000)
             - 2.5 * log10(max(fraction, 1e-4) / halfLit)
    }

    // MARK: Time & Sun

    /// Greenwich mean sidereal time, radians (IAU-82, as SGP4 users pair it).
    static func gmst(_ date: Date) -> Double {
        let jd   = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let T    = (jd - 2_451_545) / 36_525
        let secs = 67_310.548_41
                 + (876_600 * 3_600 + 8_640_184.812_866) * T
                 + 0.093_104 * T * T
                 - 6.2e-6 * T * T * T
        let rad  = (secs * .pi / 43_200).truncatingRemainder(dividingBy: 2 * .pi)
        return rad < 0 ? rad + 2 * .pi : rad
    }

    /// Unit vector to the Sun, equatorial of date (Astronomical Almanac
    /// low-precision formula, ~0.01° — far below anything a shadow edge
    /// or twilight check can notice).
    static func sunDirection(_ date: Date) -> SIMD3<Double> {
        let n    = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545
        let deg  = Double.pi / 180
        let L    = (280.460 + 0.985_647_4 * n) * deg
        let g    = (357.528 + 0.985_600_3 * n) * deg
        let λ    = L + (1.915 * sin(g) + 0.020 * sin(2 * g)) * deg
        let ε    = (23.439 - 0.000_000_4 * n) * deg
        return SIMD3(cos(λ), cos(ε) * sin(λ), sin(ε) * sin(λ))
    }

    static func rotateZ(_ v: SIMD3<Double>, by θ: Double) -> SIMD3<Double> {
        let c = cos(θ), s = sin(θ)
        return SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
    }
}

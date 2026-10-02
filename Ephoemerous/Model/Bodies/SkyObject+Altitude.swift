import Foundation
import simd
import SwiftUI      // Angle, for the sidereal offsets

// MARK: - SkyObject + Altitude
// Where any object sits against the observer's horizon at a moment — the
// one fact the search sheet's "Up now" ordering needs. Every source hands
// back the same thing: a unit direction in the equatorial frame (x toward
// the equinox, z to the celestial pole, NOT sidereally rotated), which
// `SatelliteSky.horizontal` turns into altitude for a place on Earth.
extension SkyObject {

    /// Altitude above the observer's horizon, radians; nil when there's
    /// nothing to place (a spacecraft with no orbit data for `date`).
    func altitude(at date: Date, from observer: SatelliteSky.Observer) -> Double? {
        guard let direction = equatorialDirection(at: date, from: observer) else { return nil }
        return SatelliteSky.altitude(of: direction, from: observer, date: date)
    }

    /// Unit equatorial direction (not sidereally rotated) at `date`; nil when
    /// there is nothing to place. The detail hero centres its sky on this.
    func equatorialDirection(at date: Date, from observer: SatelliteSky.Observer) -> SIMD3<Double>? {
        switch self {
        case .star(let s):
            return s.equatorialVector
        case .sun:
            return .eclipticPoint(lambda: SunPosition.eclipticLongitude(for: date))
        case .moon:
            return MoonPosition.vector(for: date, siderealOffset: .zero).vec
        case .planet(let p):
            return PlanetPosition.allVectors(for: date, siderealOffset: .zero)
                .first { $0.planet.name == p.name }?.vec
        case .constellation(let c):
            guard let anchor = ConstellationLines.shared.labelAnchors[c] else { return nil }
            return Precession.equatorialVector(ra: anchor.ra, dec: anchor.dec)
        case .spacecraft(let c):
            return SpacecraftTracker.shared.direction(of: c, at: date, from: observer)
        }
    }

    /// Apparent brightness for ordering a list, lower = brighter. A
    /// constellation has no single magnitude, so it never sorts this way.
    var orderingMagnitude: Double {
        switch self {
        case .star(let s):       return s.magnitude
        case .sun:               return -26.7
        case .moon:              return -12.7
        case .planet(let p):     return p.baseMagnitude
        case .spacecraft(let c): return c.standardMagnitude
        case .constellation:     return 0
        }
    }
}

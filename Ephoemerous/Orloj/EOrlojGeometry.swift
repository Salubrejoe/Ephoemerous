import SwiftUI

// Stereographic projection of the Prague Orloj astrolabe.
// Projection point = North celestial pole, plane = celestial equator,
// South pole at the centre. Unit of length = celestial-equator radius.
// Geometry from http://hor.cas.cz/calc-en/ — all dimensions derive from
// obliquity ε and geographic latitude φ.
struct EOrlojGeometry {

    let latitude:   Angle    // φ
    let obliquity:  Angle    // ε
    let date:       Date
    let longitude:  Angle    // observer longitude (Prague ≈ 14.42° E)
    let unitRadius: CGFloat  // celestial-equator radius, in points
    let center:     CGPoint  // plate centre in view coordinates

    private var phi: Double { latitude.radians }
    private var eps: Double { obliquity.radians }

    // MARK: - Fixed radii (multiples of the equator radius)

    var equatorRadius:        CGFloat { unitRadius }
    var tropicCancerRadius:   CGFloat { radius(forDeclination:  obliquity) } // δ = +ε, outer
    var tropicCapricornRadius: CGFloat { radius(forDeclination: -obliquity) } // δ = −ε, inner

    var eclipticRadius:         CGFloat { unitRadius * CGFloat(1.0 / cos(eps)) }
    var eclipticCentreDistance: CGFloat { unitRadius * CGFloat(tan(eps)) }

    var horizonRadius:         CGFloat { unitRadius * CGFloat(abs(1.0 / sin(phi))) }
    var horizonCentreDistance: CGFloat { unitRadius * CGFloat(1.0 / tan(phi)) } // cot φ

    /// Stereographic radius of a parallel of declination δ: r = tan(45° + δ/2).
    func radius(forDeclination dec: Angle) -> CGFloat {
        unitRadius * CGFloat(tan(.pi / 4 + dec.radians / 2))
    }

    // MARK: - Time

    var lst: Angle { EPrecession.lst(for: date, longitude: longitude) }

    // MARK: - Projection

    /// Plate point for a fixed hour angle H (used by the static tympan:
    /// horizon, unequal-hour curves). Meridian is vertical, H = 0 at top.
    func platePoint(hourAngle H: Double, declination dec: Angle) -> CGPoint {
        let r = radius(forDeclination: dec)
        return CGPoint(x: center.x + r * CGFloat(sin(H)),
                       y: center.y - r * CGFloat(cos(H)))
    }

    /// Plate point for a sky object at (RA, dec). Hour angle H = LST − RA,
    /// so the object rotates with the sky over the fixed tympan.
    func point(ra: Angle, dec: Angle) -> CGPoint {
        platePoint(hourAngle: lst.radians - ra.radians, declination: dec)
    }

    // MARK: - Horizon (fixed tympan, symmetric about the vertical meridian)

    var horizonCentre: CGPoint {
        CGPoint(x: center.x, y: center.y + horizonCentreDistance)
    }

    // MARK: - Ecliptic ring (rete — rotates with the sky)

    /// Centre of the ecliptic circle: offset toward the summer-solstice
    /// point (RA = 90°, δ = +ε) by tan(ε).
    var eclipticCentre: CGPoint {
        let hss = lst.radians - .pi / 2
        return CGPoint(x: center.x + eclipticCentreDistance * CGFloat(sin(hss)),
                       y: center.y - eclipticCentreDistance * CGFloat(cos(hss)))
    }

    /// Plate point of an ecliptic longitude λ (Sun/Moon ride this ring).
    func eclipticPoint(longitude lambda: Angle) -> CGPoint {
        let eq = ESunPosition.equatorialCoords(lambda: lambda)
        return point(ra: eq.ra, dec: eq.dec)
    }

    // MARK: - Sun & Moon (reuse existing app math)

    var sunLongitude: Angle { ESunPosition.eclipticLongitude(for: date) }

    var sunEquatorial: (ra: Angle, dec: Angle) {
        ESunPosition.equatorialCoords(lambda: sunLongitude)
    }
    var sunPoint: CGPoint { let e = sunEquatorial; return point(ra: e.ra, dec: e.dec) }

    var moonEquatorial: (ra: Angle, dec: Angle) {
        // siderealOffset only rotates the returned vector, which we ignore.
        let m = EMoonPosition.vector(for: date, siderealOffset: .zero)
        return (.degrees(m.ra), .degrees(m.dec))
    }
    var moonPoint: CGPoint { let e = moonEquatorial; return point(ra: e.ra, dec: e.dec) }

    // MARK: - Sunset

    /// Hour angle of sunset for a given declination: cos H = −tan φ · tan δ.
    /// nil during polar day / night.
    func sunsetHourAngle(declination dec: Angle) -> Double? {
        let c = -tan(phi) * tan(dec.radians)
        guard c >= -1, c <= 1 else { return nil }
        return acos(c)
    }

    // MARK: - Circle through three points (for unequal-hour arcs)

    /// Returns the centre and radius of the circle through a, b, c —
    /// or nil if the points are (near) collinear.
    static func circle(through a: CGPoint, _ b: CGPoint, _ c: CGPoint)
        -> (centre: CGPoint, radius: CGFloat)? {
        let d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
        guard abs(d) > 1e-6 else { return nil }
        let a2 = a.x * a.x + a.y * a.y
        let b2 = b.x * b.x + b.y * b.y
        let c2 = c.x * c.x + c.y * c.y
        let ux = (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d
        let uy = (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d
        let centre = CGPoint(x: ux, y: uy)
        return (centre, hypot(a.x - ux, a.y - uy))
    }
}

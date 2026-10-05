import SwiftUI
import simd
import LoreKit

// MARK: - SkyLabObjects
// Projection + POI-descriptor helpers shared by the tap hit-test (which
// enumerates every tappable object) and the promoted-label overlay (which
// re-projects the ONE selected object each frame). Mirrors the position
// sources in SkyLabBodiesOverlay / SkyLabConstellationLabelsOverlay so a
// hit-test lands exactly on what's drawn, and bodies track the clock.
enum SkyLabObjects {

    /// Screen point (oversized-canvas coords) for any sky object, via the
    /// matching projection path. `nil` when it projects behind the viewer
    /// or has no anchor. Bodies recompute from `date` so the mark tracks
    /// the moving object.
    /// `liveDate` only moves spacecraft (see `SkyCamera.screen(_:skyDate:liveDate:)`).
    static func screen(_ obj: SkyObject, camera: SkyCamera, date: Date, liveDate: Date? = nil) -> CGPoint? {
        switch obj {
        case .star(let s):
            return camera.screen(equatorial: s.equatorialVector)
        case .sun:
            let lambda = SunPosition.eclipticLongitude(for: date)
            return camera.screen(equatorial: .eclipticPoint(lambda: lambda))
        case .moon:
            let (vec, _, _) = MoonPosition.vector(for: date, siderealOffset: camera.sidereal)
            return camera.screen(rotatedEquatorial: vec)
        case .planet(let p):
            guard let match = PlanetPosition
                .allVectors(for: date, siderealOffset: camera.sidereal)
                .first(where: { $0.0.name == p.name }) else { return nil }
            return camera.screen(rotatedEquatorial: match.1)
        case .constellation(let c):
            guard let anchor = ConstellationLines.shared.labelAnchors[c] else { return nil }
            let q = Precession.equatorialVector(ra: anchor.ra, dec: anchor.dec)
            return camera.screen(equatorial: q)
        case .spacecraft(let c):
            return camera.screen(c, skyDate: date, liveDate: liveDate)
        }
    }

    /// The object's direction in the projection's sidereally-rotated frame —
    /// the frame `camera.viewpoint.originVector` (the zenith) lives in, so a
    /// dot product with it is the sine of the object's altitude. `nil` for
    /// spacecraft, which project through their own pipeline.
    static func rotatedVector(_ obj: SkyObject, camera: SkyCamera, date: Date) -> SIMD3<Double>? {
        switch obj {
        case .star(let s):
            return s.equatorialVector.sidereallyRotated(by: camera.sidereal)
        case .sun:
            let lambda = SunPosition.eclipticLongitude(for: date)
            return SIMD3<Double>.eclipticPoint(lambda: lambda).sidereallyRotated(by: camera.sidereal)
        case .moon:
            return MoonPosition.vector(for: date, siderealOffset: camera.sidereal).vec
        case .planet(let p):
            return PlanetPosition.allVectors(for: date, siderealOffset: camera.sidereal)
                .first(where: { $0.planet.name == p.name })?.vec
        case .constellation(let c):
            guard let anchor = ConstellationLines.shared.labelAnchors[c] else { return nil }
            return Precession.equatorialVector(ra: anchor.ra, dec: anchor.dec).sidereallyRotated(by: camera.sidereal)
        case .spacecraft:
            return nil
        }
    }

    /// POI descriptor (category + glyph + name) for the badge-style objects.
    /// `nil` for constellations — they promote as an emphasised NAME in
    /// place (no badge), like production's `isSelected` label.
    static func poiMark(_ obj: SkyObject, date: Date)
        -> (category: POICategory, glyph: POIGlyph, name: String)? {
        let a = Artist.shared
        switch obj {
        case .star(let s):
            return (.followedStar(s), .sfSymbol("star.fill"), s.displayName)
        case .sun:
            return (.sun, .symbol(.sunMaxFill), Strings.Bodies.sun)
        case .moon:
            // Latitude only mirrors the DRAWN badge, not the glyph name,
            // so the Lab's flat symbol can take the equator.
            let phase = MoonPosition.phase(for: date, latitude: .zero)
            return (.moon, .symbol(a.moonPhaseSymbol(phase)), Strings.Bodies.moon)
        case .planet(let p):
            return (.planet(p), .unicode(a.planetGlyph(p)), p.displayName)
        case .constellation:
            return nil
        case .spacecraft(let c):
            return (.spacecraft(c), .sfSymbol("antenna.radiowaves.left.and.right"), c.displayName)
        }
    }
}

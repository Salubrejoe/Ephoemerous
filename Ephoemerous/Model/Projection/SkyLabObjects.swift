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
    static func screen(_ obj: ESkyObject, camera: SkyCamera, date: Date) -> CGPoint? {
        switch obj {
        case .star(let s):
            return camera.screen(equatorial: s.equatorialVector)
        case .sun:
            let lambda = ESunPosition.eclipticLongitude(for: date)
            return camera.screen(equatorial: .eclipticPoint(lambda: lambda))
        case .moon:
            let (vec, _, _) = EMoonPosition.vector(for: date, siderealOffset: camera.sidereal)
            return camera.screen(rotatedEquatorial: vec)
        case .planet(let p):
            guard let match = EPlanetPosition
                .allVectors(for: date, siderealOffset: camera.sidereal)
                .first(where: { $0.0.name == p.name }) else { return nil }
            return camera.screen(rotatedEquatorial: match.1)
        case .constellation(let c):
            guard let anchor = ConstellationLines.shared.labelAnchors[c] else { return nil }
            let q = EPrecession.equatorialVector(ra: anchor.ra, dec: anchor.dec)
            return camera.screen(equatorial: q)
        }
    }

    /// POI descriptor (category + glyph + name) for the badge-style objects.
    /// `nil` for constellations — they promote as an emphasised NAME in
    /// place (no badge), like production's `isSelected` label.
    static func poiMark(_ obj: ESkyObject, date: Date)
        -> (category: POICategory, glyph: POIGlyph, name: String)? {
        let a = EArtist.shared
        switch obj {
        case .star(let s):
            return (.followedStar(s), .sfSymbol("star.fill"), s.displayName)
        case .sun:
            return (.sun, .symbol(.sunMaxFill), Strings.Bodies.sun)
        case .moon:
            let frac = EMoonPosition.illuminatedFraction(for: date)
            return (.moon, .symbol(a.moonPhaseSymbol(fraction: frac)), Strings.Bodies.moon)
        case .planet(let p):
            return (.planet(p), .unicode(a.planetGlyph(p)), p.displayName)
        case .constellation:
            return nil
        }
    }
}

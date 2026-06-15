import SwiftUI
import simd
import LoreKit

// MARK: - SkyLabBodiesOverlay
// The solar-system bodies — Sun, Moon, planets — as NATIVE POI labels
// (the `POILabelView` component). Each is positioned at its projected
// screen point via the SAME committed camera the Canvas layers draw with,
// and counter-scaled by `1/pinch` so the badge holds a constant screen
// size while still tracking its sky point through a zoom.
//
// Position sources mirror the production layers: the Sun is an ecliptic
// point (un-rotated → `screen(equatorial:)`), while the Moon and planet
// helpers return vectors ALREADY sidereally rotated (→
// `screen(rotatedEquatorial:)`). The stress test for multiple
// constant-size native overlays sharing one parent transform.
struct SkyLabBodiesOverlay: View {

    let camera: SkyLabCamera
    let date:   Date
    let pinch:  CGFloat
    /// Live (clamped) scale — gates each body by its category tier. Sun /
    /// Moon are `badgeIn 0` (always), planets `badgeIn 80`; names follow
    /// at each `textIn`.
    let scale:  CGFloat

    private var artist: EArtist { .shared }

    var body: some View {
        ZStack {
            marker(at: sunScreen,
                   category: .sun,
                   glyph:    .symbol(.sunMaxFill),
                   text:     Strings.Bodies.sun)

            marker(at: moonScreen,
                   category: .moon,
                   glyph:    .symbol(artist.moonPhaseSymbol(
                                fraction: EMoonPosition.illuminatedFraction(for: date))),
                   text:     Strings.Bodies.moon)

            ForEach(planetMarks, id: \.id) { mark in
                marker(at: mark.sc,
                       category: .planet(mark.planet),
                       glyph:    .unicode(artist.planetGlyph(mark.planet)),
                       text:     mark.planet.displayName)
            }
        }
    }

    /// One positioned, constant-size label (or nothing if it doesn't
    /// project). The `1/pinch` counter-scale + `.position` is the shared
    /// recipe for every native overlay — see SkyLabSunLabel's note.
    @ViewBuilder
    private func marker(at sc: CGPoint?,
                        category: POICategory,
                        glyph: POIGlyph,
                        text: String) -> some View {
        if let sc {
            let style = artist.poiStyle(for: category)
            if scale >= style.badgeIn {        // tier gate (Sun/Moon = 0)
                POILabelView(category:  category,
                             glyph:     glyph,
                             text:      text,
                             showsName: scale >= style.textIn)
                    .scaleEffect(1 / pinch)
                    .position(sc)
            }
        }
    }

    // MARK: Positions

    private var sunScreen: CGPoint? {
        let lambda = ESunPosition.eclipticLongitude(for: date)
        return camera.screen(equatorial: .eclipticPoint(lambda: lambda))
    }

    private var moonScreen: CGPoint? {
        let (vec, _, _) = EMoonPosition.vector(for: date, siderealOffset: camera.sidereal)
        return camera.screen(rotatedEquatorial: vec)
    }

    private struct PlanetMark: Identifiable {
        let planet: EPlanet
        let sc:     CGPoint
        var id: String { planet.name }
    }

    private var planetMarks: [PlanetMark] {
        EPlanetPosition.allVectors(for: date, siderealOffset: camera.sidereal)
            .compactMap { planet, vec, _, _ in
                camera.screen(rotatedEquatorial: vec).map { PlanetMark(planet: planet, sc: $0) }
            }
    }
}

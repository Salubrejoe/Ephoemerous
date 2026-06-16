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
    /// Live map rotation — counter-rotated per label so the badge stays
    /// screen-upright while the sky spins (Apple-Maps).
    var rotation: Angle = .zero
    /// Selected body is drawn by the promoted overlay instead — skip it
    /// here so its badge isn't drawn twice.
    var selected: ESkyObject? = nil

    private var artist: EArtist { .shared }

    var body: some View {
        ZStack {
            ForEach(planetMarks, id: \.id) { mark in
                marker(for: .planet(mark.planet),
                       at: mark.sc,
                       category: .planet(mark.planet),
                       glyph:    .unicode(artist.planetGlyph(mark.planet)),
                       text:     mark.planet.displayName)
            }
            
            marker(for: .sun,
                   at: sunScreen,
                   category: .sun,
                   glyph:    .symbol(.sunMaxFill),
                   text:     Strings.Bodies.sun,
                   labelStyle: .star)

            marker(for: .moon,
                   at: moonScreen,
                   category: .moon,
                   glyph:    .symbol(artist.moonPhaseSymbol(
                                fraction: EMoonPosition.illuminatedFraction(for: date))),
                   text:     Strings.Bodies.moon)

        }
    }

    /// One positioned, constant-size label (or nothing if it doesn't
    /// project / is the promoted selection). The `1/pinch` counter-scale +
    /// `.position` is the shared recipe for every native overlay.
    @ViewBuilder
    private func marker(for object: ESkyObject,
                        at sc: CGPoint?,
                        category: POICategory,
                        glyph: POIGlyph,
                        text: String,
                        labelStyle: POILabelView.LabelStyle = .planetoids) -> some View {
        if let sc, object != selected {
            let style = artist.poiStyle(for: category)
            if scale >= style.badgeIn {        // badge tier gate (Sun/Moon = 0)
                POILabelView(category:    category,
                             glyph:       glyph,
                             text:        text,
                             labelStyle: labelStyle,
                             badgeReveal: POILabelView.tierReveal(scale: scale, threshold: style.badgeIn),
                             nameReveal:  POILabelView.tierReveal(scale: scale, threshold: style.textIn))
                    .rotationEffect(-rotation, anchor: .center)
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

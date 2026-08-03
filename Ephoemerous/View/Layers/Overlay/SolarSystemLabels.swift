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
struct SolarSystemLabels: View {

    let camera: SkyCamera
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
    var selected: SkyObject? = nil

    private var artist: Artist { .shared }

    var body: some View {
        // Declutter: labels never overlap. Priority runs Sun > Moon >
        // planets (catalogue order among planets) — a lower body whose
        // label would collide with a higher one drops to badge-only
        // (conjunctions are exactly when people look; "cLuna" stamped over
        // "Sole" is the #1 amateur tell on a map).
        let sun   = sunScreen
        let moon  = moonScreen
        let marks = planetMarks

        ZStack {
            ForEach(Array(marks.enumerated()), id: \.element.id) { i, mark in
                // Tier-0 dot — a planet reads as a small tinted dot until
                // its badge tier, then crossfades into the badge. Skipped
                // for the selected planet (the promoted pin stands in).
                if selected != .planet(mark.planet) {
                    let style = artist.poiStyle(for: .planet(mark.planet))
                    let badge = POILabelView.tierReveal(scale: scale, threshold: style.badgeIn)
                    if badge < 1 {
                        Circle()
                            .fill(style.gradientBottom)
                            .frame(width: style.dotRadius * 2, height: style.dotRadius * 2)
                            .opacity(1 - badge)
                            .scaleEffect(1 / pinch)
                            .position(mark.sc)
                    }
                }
                marker(for: .planet(mark.planet),
                       at: mark.sc,
                       category: .planet(mark.planet),
                       text:     mark.planet.displayName,
                       suppressName: nameCollides(mark.sc,
                                                  with: [sun, moon] + marks.prefix(i).map(\.sc)))
            }

            marker(for: .sun,
                   at: sunScreen,
                   category: .sun,
                   text:     Strings.Bodies.sun,
                   labelStyle: .star)

            marker(for: .moon,
                   at: moonScreen,
                   category: .moon,
                   text:     Strings.Bodies.moon,
                   suppressName: nameCollides(moon, with: [sun]))

        }
    }

    /// True when a body's label box would overlap a higher-priority
    /// body's. Labels extend trailing of the badge, so the box is generous
    /// horizontally, tight vertically. ▼ TWEAK the collision box here ▼
    private func nameCollides(_ sc: CGPoint?, with higher: [CGPoint?]) -> Bool {
        guard let sc else { return false }
        return higher.compactMap { $0 }.contains {
            abs(sc.x - $0.x) < 110 && abs(sc.y - $0.y) < 22
        }
    }

    /// One positioned, constant-size label (or nothing if it doesn't
    /// project / is the promoted selection). The `1/pinch` counter-scale +
    /// `.position` is the shared recipe for every native overlay.
    /// `suppressName` drops the label to badge-only (collision declutter).
    @ViewBuilder
    private func marker(for object: SkyObject,
                        at sc: CGPoint?,
                        category: POICategory,
                        text: String,
                        labelStyle: POILabelView.LabelStyle = .planetoids,
                        suppressName: Bool = false) -> some View {
        if let sc, object != selected {
            let style = artist.poiStyle(for: category)
            if scale >= style.badgeIn {        // badge tier gate (Sun/Moon = 0)
                POILabelView(category:    category,
                             text:        text,
                             labelStyle: labelStyle,
                             badgeReveal: POILabelView.tierReveal(scale: scale, threshold: style.badgeIn),
                             nameReveal:  suppressName ? 0
                                 : POILabelView.tierReveal(scale: scale, threshold: style.textIn))
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    .position(sc)
            }
        }
    }

    // MARK: Positions

    private var sunScreen: CGPoint? {
        let lambda = SunPosition.eclipticLongitude(for: date)
        return camera.screen(equatorial: .eclipticPoint(lambda: lambda))
    }

    private var moonScreen: CGPoint? {
        let (vec, _, _) = MoonPosition.vector(for: date, siderealOffset: camera.sidereal)
        return camera.screen(rotatedEquatorial: vec)
    }

    private struct PlanetMark: Identifiable {
        let planet: Planet
        let sc:     CGPoint
        var id: String { planet.name }
    }

    private var planetMarks: [PlanetMark] {
        PlanetPosition.allVectors(for: date, siderealOffset: camera.sidereal)
            .compactMap { planet, vec, _, _ in
                camera.screen(rotatedEquatorial: vec).map { PlanetMark(planet: planet, sc: $0) }
            }
    }
}

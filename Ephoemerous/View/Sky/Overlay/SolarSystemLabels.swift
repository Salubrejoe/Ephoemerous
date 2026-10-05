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
    /// The observation is "now" — spacecraft then ride the wall clock
    /// while everything else holds the frozen `date`.
    var spacecraftLive: Bool = false
    /// Names fade outside the calm middle of the screen; badges stay.
    var comfort: LabelComfortZone = .everywhere

    private var artist: Artist { .shared }

    /// The marks grow with the Text Size, so the declutter box does too.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Declutter: labels never overlap. Priority runs Sun > Moon >
        // planets (catalogue order among planets) — a lower body whose
        // label would collide with a higher one drops to badge-only
        // (conjunctions are exactly when people look; "cLuna" stamped over
        // "Sole" is the #1 amateur tell on a map).
        let sun   = sunScreen
        let moon  = moonScreen
        let marks = planetMarks
        let bodies: [CGPoint?] = [sun, moon] + marks.map(\.sc)

        ZStack {
            ForEach(Array(marks.enumerated()), id: \.element.id) { i, mark in
                // Tier-0 dot — a planet reads as a small tinted dot until
                // its badge tier, then crossfades into the badge. Skipped
                // for the selected planet (the promoted pin stands in).
                if selected != .planet(mark.planet) {
                    tierDot(for: .planet(mark.planet), at: mark.sc)
                }
                marker(for: .planet(mark.planet),
                       at: mark.sc,
                       category: .planet(mark.planet),
                       text:     mark.planet.displayName,
                       suppressName: nameCollides(mark.sc,
                                                  with: [sun, moon] + marks.prefix(i).map(\.sc)))
            }

            spacecraftLayer(below: bodies)

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

    // MARK: Spacecraft

    /// Spacecraft — last in the declutter order: a craft's name gives way
    /// to every natural body, and to the craft before it. Live, the layer
    /// redraws at `SpacecraftTracker.liveFrameInterval`; frozen, it's static.
    ///
    /// No implicit animation on purpose: a tween keyed to the clock would
    /// also catch the gesture commit (the camera re-bases every point at
    /// once) and send the badge sliding in from a stale spot.
    @ViewBuilder
    private func spacecraftLayer(below bodies: [CGPoint?]) -> some View {
        if spacecraftLive {
            TimelineView(.animation(minimumInterval: SpacecraftTracker.liveFrameInterval)) { tick in
                spacecraftMarkers(below: bodies, liveDate: tick.date)
            }
        } else {
            spacecraftMarkers(below: bodies, liveDate: nil)
        }
    }

    private func spacecraftMarkers(below bodies: [CGPoint?], liveDate: Date?) -> some View {
        let craft = spacecraftMarks(liveDate: liveDate)
        return ZStack {
            ForEach(Array(craft.enumerated()), id: \.element.id) { i, mark in
                ZStack {
                    if selected != .spacecraft(mark.craft) {
                        tierDot(for: .spacecraft(mark.craft), at: mark.sc)
                    }
                    marker(for: .spacecraft(mark.craft),
                           at: mark.sc,
                           category: .spacecraft(mark.craft),
                           text:     mark.craft.displayName,
                           suppressName: nameCollides(mark.sc,
                                                      with: bodies + craft.prefix(i).map(\.sc)))
                }
            }
        }
    }

    /// Tier-0 dot — a small tinted dot that crossfades into the badge as
    /// the zoom reaches its tier.
    @ViewBuilder
    private func tierDot(for category: POICategory, at sc: CGPoint) -> some View {
        let style = artist.poiStyle(for: category)
        let badge = POILabelView.tierReveal(scale: scale, threshold: style.badgeIn)
        if badge < 1 {
            Circle()
                .fill(style.gradientBottom)
                .frame(width: style.dotRadius * 2, height: style.dotRadius * 2)
                .opacity(1 - badge)
                .scaleEffect(1 / pinch)
                .position(sc)
        }
    }

    /// True when a body's label box would overlap a higher-priority
    /// body's. Labels extend trailing of the badge, so the box is generous
    /// horizontally, tight vertically — at the default Text Size, grown
    /// with it. ▼ TWEAK the collision box here ▼
    private func nameCollides(_ sc: CGPoint?, with higher: [CGPoint?]) -> Bool {
        guard let sc else { return false }
        let type = artist.typeScale(dynamicTypeSize)
        return higher.compactMap { $0 }.contains {
            abs(sc.x - $0.x) < 110 * type && abs(sc.y - $0.y) < 22 * type
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
                                 : POILabelView.tierReveal(scale: scale, threshold: style.textIn)
                                   * comfort.nameVisibility(at: sc),
                             phase:       lunarPhase(for: category))
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    .position(sc)
            }
        }
    }

    /// The Moon's and Venus's badges draw their real phase; every other body
    /// ignores this. Latitude comes off the camera (see
    /// `SkyCamera.observerLatitude`) — the phase mirrors in the south.
    private func lunarPhase(for category: POICategory) -> LunarPhase? {
        BadgePhase.of(category, date: date, latitude: camera.observerLatitude)
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

    private struct SpacecraftMark: Identifiable {
        let craft: Spacecraft
        let sc:    CGPoint
        var id: String { craft.rawValue }
    }

    private func spacecraftMarks(liveDate: Date?) -> [SpacecraftMark] {
        Spacecraft.allCases.compactMap { craft in
            camera.screen(craft, skyDate: date, liveDate: liveDate)
                .map { SpacecraftMark(craft: craft, sc: $0) }
        }
    }

    private var planetMarks: [PlanetMark] {
        PlanetPosition.allVectors(for: date, siderealOffset: camera.sidereal)
            .compactMap { planet, vec, _, _ in
                camera.screen(rotatedEquatorial: vec).map { PlanetMark(planet: planet, sc: $0) }
            }
    }
}

#if DEBUG
#Preview("Sun, Moon, planets") {
    PreviewSky.night {
        SolarSystemLabels(camera: PreviewSky.camera,
                          date: PreviewSky.date,
                          pinch: 1, scale: 220, rotation: .zero,
                          selected: nil)
    }
}
#endif

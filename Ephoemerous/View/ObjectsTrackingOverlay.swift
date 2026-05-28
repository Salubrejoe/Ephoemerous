
import SwiftUI
import LoreKit

// MARK: - ObjectsTrackingOverlay
// Invisible hit-test layer on top of the canvas. Each child is a clear
// shape positioned over the projected screen point of a tappable POI;
// tapping calls `state.focus(on:)`, which sets `detailDestination` and
// pans the camera. The sheet itself is hosted at `MainView` root — this
// layer is purely about turning taps into intents.
struct ObjectsTrackingOverlay: View {
    @Environment(EAppState.self) var state

    var body: some View {
        // Z-ordering matters: SwiftUI hit-tests top-to-bottom and the
        // first match wins. Anything rendered later in this ZStack
        // sits *above* the earlier siblings and gets first crack at
        // taps. So we lay down planets first (they're the "smaller
        // fish") and put sun/moon on top — when a tap lands in
        // overlapping targets near the ecliptic (Mercury/Venus
        // near the sun, conjunctions, etc.) the bigger body wins.
        ZStack {
            // Planets — published per frame by EPlanetsLayer, keyed
            // by planet.name. Linear lookup is fine: there are only 7.
            ForEach(Array(state.planetPositions), id: \.key) { name, point in
                if let planet = EPlanet.all.first(where: { $0.name == name }) {
                    ClearCircle(at: point, size: planetHitSize)
                        .onTapGesture { state.focus(on: .planet(planet)) }
                }
            }

            // Favourited stars become tappable wherever the
            // FavouritesLayer published their position. Keyed by
            // `ESkyObject.id` so it generalises beyond stars later.
            ForEach(state.favouriteStars.uniqued(by: \.name), id: \.name) { star in
                if let point = state.favouritePositions[ESkyObject.star(star).id] {
                    ClearCircle(at: point, size: starHitSize)
                        .onTapGesture { state.focus(on: .star(star)) }
                }
            }

            ForEach(Array(state.constellationLabelHitRects), id: \.key) { cons, rect in
                ClearCapsule(in: rect)
                    .onTapGesture { state.focus(on: .constellation(cons)) }
            }

            // Proper-named stars become tappable above
            // `namedStarTapMinScale`. The dict is keyed by the
            // catalogue name; NamedStarsLayer hands us back the EStar.
            ForEach(Array(state.namedStarHitRects), id: \.key) { name, rect in
                if let star = NamedStarsLayer.star(named: name) {
                    ClearCapsule(in: rect)
                        .onTapGesture { state.focus(on: .star(star)) }
                }
            }

            // Sun and moon are rendered *last* so they sit on top
            // and win tap conflicts with planets clustered around
            // them — the user is almost always aiming at the bigger
            // body when both are under the same finger.
            if let moonPoint = state.moonScreenPosition {
                ClearCircle(at: moonPoint, size: moonHitSize)
                    .onTapGesture { state.focus(on: .moon) }
            }

            if let sunPoint = state.sunScreenPosition {
                ClearCircle(at: sunPoint, size: sunHitSize)
                    .onTapGesture { state.focus(on: .sun) }
            }
        }
        .allowsHitTesting(true)
        .ignoresSafeArea()
    }

    // MARK: - Hit sizing
    //
    // Each kind of POI gets its own target diameter, biased by how
    // prominent the body is on screen. Sun > moon > planets, matching
    // their badge sizes in EArtist+POILabel.swift (22 / 18 / 15 pt).
    //
    // Planet targets shrink at low scale where the badges themselves
    // are barely visible specks — there's no point claiming a 44pt
    // bubble for a 2-pixel dot the user can't even see yet. Once
    // they've zoomed in enough to actually be aiming at a planet,
    // the target grows back to the full 44pt accessibility floor.

    /// Sun gets the largest target — it's the visual anchor of the
    /// daytime sky and the user is almost always intending to hit it
    /// when their finger lands anywhere near.
    private var sunHitSize: CGFloat { 56 }

    /// Moon slightly smaller than sun, still comfortably above the
    /// 44pt accessibility floor.
    private var moonHitSize: CGFloat { 48 }

    /// Planets scale from 28pt (barely-rendered specks at low zoom)
    /// up to 44pt once the user is zoomed in enough that they're
    /// clearly aiming. Threshold range 80 → 280 mirrors the
    /// `badgeIn` gate in EArtist+POILabel.swift — below 80 the
    /// badge hasn't really materialised, so the hit area shouldn't
    /// be aggressive about claiming taps.
    private var planetHitSize: CGFloat {
        let t = max(0, min(1, (state.scale - 80) / 200))
        return 28 + 16 * t
    }

    /// Favourited stars use the same scaling as planets — the heart
    /// marker is small and shouldn't steal taps from sun/moon when
    /// zoomed out.
    private var starHitSize: CGFloat { planetHitSize }

    @ViewBuilder
    private func ClearCircle(at point: CGPoint, size: CGFloat) -> some View {
        Circle()
            .fill(Color.clear)
            .contentShape(Circle())
            .frame(width: size, height: size)
            .position(point)
    }

    // Constellation tap target — a capsule sized to hug the rendered
    // label (see ConstellationNamesLayer). Fill is `.clear` so it stays
    // invisible; flip to `.white` like `ClearCircle` above to eyeball
    // the hit areas while debugging.
    @ViewBuilder
    private func ClearCapsule(in rect: CGRect) -> some View {
        Capsule()
            .fill(Color.clear)
            .contentShape(Capsule())
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}


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
        ZStack {
            if let sunPoint = state.sunScreenPosition {
                ClearCircle(at: sunPoint)
                    .onTapGesture { state.focus(on: .sun) }
            }

            if let moonPoint = state.moonScreenPosition {
                ClearCircle(at: moonPoint)
                    .onTapGesture { state.focus(on: .moon) }
            }

            // Planets — published per frame by EPlanetsLayer, keyed
            // by planet.name. Linear lookup is fine: there are only 7.
            ForEach(Array(state.planetPositions), id: \.key) { name, point in
                if let planet = EPlanet.all.first(where: { $0.name == name }) {
                    ClearCircle(at: point)
                        .onTapGesture { state.focus(on: .planet(planet)) }
                }
            }

            // Favourited stars become tappable wherever the
            // FavouritesLayer published their position. Keyed by
            // `ESkyObject.id` so it generalises beyond stars later.
            ForEach(state.favouriteStars.uniqued(by: \.name), id: \.name) { star in
                if let point = state.favouritePositions[ESkyObject.star(star).id] {
                    ClearCircle(at: point)
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
        }
        .allowsHitTesting(true)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func ClearCircle(at point: CGPoint) -> some View {
        Circle()
            .fill(Color.clear)
            .contentShape(Circle())
            .frame(width: 44, height: 44)
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

import SwiftUI

// MARK: - SkyLayerStack
// The sky itself, back to front. Every layer draws through the one
// `SkyFrame` camera, so nothing can disagree about where a star is.
//
// THE SYNC RULE this stack exists to honour: the `.equatable()` Canvases
// redraw only when the COMMITTED camera changes (a settle, a date or origin
// move) — never per gesture frame. The live pinch/rotate/pan is a single
// parent transform applied by the caller, so frozen Canvases and native
// overlays move together in one CoreAnimation commit and cannot desync.
//
// Order matters and is the whole composition:
//   grid → puck → horizon rings → figures → star field → named dots
//   → frosted ground → cartography → labels → the promoted pin on top.
struct SkyLayerStack: View {

    @Environment(AppState.self) private var app
    let frame: SkyFrame

    var body: some View {
        ZStack {
            // Deepens the visible sky, UNDER everything that draws on it —
            // marks keep their brightness, only their ground goes down.
            HorizonSkyVeil(camera: frame.camera)

            CelestialGridCanvas(camera: frame.camera)
                .equatable()

            // "You are here" — aim cone + globe puck at the zenith.
            PuckAndConeOverlay(camera: frame.camera, pinch: frame.effPinch)

            // The horizon ring, concentric about the zenith.
            EarthGridOverlay(camera: frame.camera)

            // Constellation stick-figures; favourites stroke solid, the rest
            // ride in on the constellation-NAME tier (same threshold, same
            // smoothstep) so figures and names arrive together.
            ConstellationLinesCanvas(camera: frame.camera,
                                     favouriteTints: frame.favouriteConstellationTints,
                                     reveal: ConstellationLinesCanvas.reveal(scale: frame.liveScale))

            StarsCanvas(camera: frame.camera,
                        stars: app.sortedStars,
                        favouriteIDs: frame.favouriteIDs,
                        namedIDs: frame.namedIDs)
                .equatable()

            // Tier-0 spectral dots for proper-named stars — appear past
            // `namedStarDotIn`, crossfade into the badge.
            NamedStarDotsCanvas(camera: frame.camera,
                                stars: frame.namedOnly,
                                scale: frame.liveScale,
                                selectedID: frame.selectedStarID)
                .equatable()

            // Frosted pane over the ground below the horizon, recomputed from
            // the morphing camera so it deforms live through NorthIN↔NorthOUT.
            // Above the star canvases (the ground frosts), below the labels
            // (they stay sharp).
            HorizonBlurOverlay(camera: frame.camera)

            // Curved cartographic labels — horizon rim + colures.
            CartographyLabels(camera: frame.camera,
                              latitude: app.origin.latitude,
                              date: app.renderedObservationDate,
                              visibleRect: frame.visibleRect)
                .equatable()

            // Tiered native labels — each reveals at its own zoom tier.
            ConstellationLabels(camera: frame.camera,
                                pinch: frame.effPinch,
                                scale: frame.liveScale,
                                rotation: frame.liveRot,
                                selectedID: frame.selectedConsID)

            StarLabels(camera: frame.camera,
                       stars: app.favouriteStars,
                       pinch: frame.effPinch,
                       scale: frame.liveScale,
                       rotation: frame.liveRot,
                       category: { .followedStar($0) },
                       selectedID: frame.selectedStarID)

            // Favourite-star heart, except the selected one — the promoted
            // pin carries its own.
            FavouriteHeart(camera: frame.camera,
                           stars: app.favouriteStars,
                           pinch: frame.effPinch,
                           scale: frame.liveScale,
                           rotation: frame.liveRot,
                           selectedID: frame.selectedStarID)

            StarLabels(camera: frame.camera,
                       stars: frame.namedOnly,
                       pinch: frame.effPinch,
                       scale: frame.liveScale,
                       rotation: frame.liveRot,
                       category: { .namedStar($0) },
                       selectedID: frame.selectedStarID)

            SolarSystemLabels(camera: frame.camera,
                              date: app.renderedObservationDate,
                              pinch: frame.effPinch,
                              scale: frame.liveScale,
                              rotation: frame.liveRot,
                              selected: frame.selection)

            // The selected object, forced visible at any zoom — topmost so it
            // reads above the passive labels.
            PromotedLabel(camera: frame.camera,
                          selection: frame.selection,
                          date: app.renderedObservationDate,
                          pinch: frame.effPinch,
                          rotation: frame.liveRot,
                          isFavourite: frame.selection.map(app.isFavourite) ?? false)
        }
    }
}

#if DEBUG
// The whole sky in one preview — every layer, one camera. Needs a real
// `SkyFrame`, so it builds one from a fresh app state and camera.
#Preview("All layers") {
    let app = AppState()
    return PreviewSky.night {
        SkyLayerStack(frame: SkyFrame(app: app,
                                      sky: MainGestureCoordinator(),
                                      geoSize: PreviewSky.size,
                                      overdraw: 0,
                                      compassEngage: 0,
                                      morphScaleFrom: 0,
                                      morphOffsetFrom: .zero))
    }
    .environment(app)
}
#endif

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
//   grid → facing bezel → figures → star field → named dots
//   → frosted ground → cartography → labels → look crosshair → the
//   promoted pin on top.
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

            // Where you face — a softly lit stretch of the horizon rim
            // (see `Artist+Aim`).
            FacingBezel(camera: frame.camera)
                .opacity(1 - frame.lookBlend)       // the window needs no bezel

            // Constellation stick-figures; favourites stroke solid, the rest
            // ride in on the constellation-NAME tier (same threshold, same
            // smoothstep) so figures and names arrive together.
            ConstellationLinesCanvas(camera: frame.camera,
                                     favouriteTints: frame.favouriteConstellationTints,
                                     favouriteIDs: frame.favouriteIDs,
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
                                selectedID: frame.selectedStarID,
                                dotOnly: frame.starLabels.dotOnly)
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
                                selectedID: frame.selectedConsID,
                                comfort: frame.comfort,
                                layout: frame.starLabels)

            // The quietest voice, so it paints FIRST and every louder label
            // lands on top of it: bare Greek letters on the figure stars
            // nobody ever named. Purely an annotation — no badge, no tap.
            BayerLabels(camera: frame.camera,
                        stars: frame.bayerOnly,
                        pinch: frame.effPinch,
                        scale: frame.liveScale,
                        rotation: frame.liveRot,
                        selectedID: frame.selectedStarID,
                        comfort: frame.comfort)

            StarLabels(camera: frame.camera,
                       stars: app.favouriteStars,
                       pinch: frame.effPinch,
                       scale: frame.liveScale,
                       rotation: frame.liveRot,
                       category: { .followedStar($0) },
                       selectedID: frame.selectedStarID,
                       comfort: frame.comfort,
                       layout: frame.starLabels)

            // Pinned stars' tier-0 dots, except the selected one — the
            // promoted pin carries its own.
            PinnedStarDots(camera: frame.camera,
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
                       selectedID: frame.selectedStarID,
                       comfort: frame.comfort,
                       layout: frame.starLabels)

            SolarSystemLabels(camera: frame.camera,
                              date: app.renderedObservationDate,
                              pinch: frame.effPinch,
                              scale: frame.liveScale,
                              rotation: frame.liveRot,
                              selected: frame.selection,
                              spacecraftLive: app.isObservationLive,
                              comfort: frame.comfort)

            // LOOK mode's sight — fixed at the screen's centre while the sky
            // moves under it; with something selected, it hunts for it.
            // Above the labels, below the pin.
            LookCrosshair(camera: frame.camera,
                          date: app.renderedObservationDate,
                          centre: CGPoint(x: frame.visibleRect.midX, y: frame.visibleRect.midY),
                          blend: frame.lookBlend,
                          target: frame.selection)

            // The selected object, forced visible at any zoom — topmost so it
            // reads above the passive labels.
            PromotedLabel(camera: frame.camera,
                          selection: frame.selection,
                          date: app.renderedObservationDate,
                          pinch: frame.effPinch,
                          rotation: frame.liveRot,
                          isFavourite: frame.selection.map(app.isFavourite) ?? false,
                          spacecraftLive: app.isObservationLive)
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

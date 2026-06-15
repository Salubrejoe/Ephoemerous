import SwiftUI

// MARK: - SkyLabView
// Proving ground for the rendering rethink: a Canvas layer (the grid) and
// a native SwiftUI overlay (the Sun label) under ONE shared parent
// transform.
//
// The sync model — the thing this view exists to validate:
//   • Both children render at the camera's COMMITTED (resting) transform.
//   • A live gesture writes only the transient `drag` / `pinch`, which
//     drive a single `.scaleEffect` + `.offset` on the ZStack that holds
//     BOTH children. A parent transform lands on every child in the same
//     CoreAnimation commit, so the Canvas and the overlay move as one and
//     cannot desync — no per-frame re-projection, no two clocks.
//   • On release the delta folds into the committed transform and resets
//     to identity: one reconciliation render at the new camera.
//
// Astronomical data (viewpoint, sidereal time, date) is read from the
// shared `EAppState`; the camera transform is the lab's own.
//
// To run it as the app root, swap `MainView()` for `SkyLabView()` in
// `EphoemerousApp` (kept out of production by default).
struct SkyLabView: View {

    @Environment(EAppState.self) private var app

    /// Camera + gesture engine — committed camera (scale/offset/rotation)
    /// frozen during a gesture, live deltas drive the parent transform,
    /// folded once on release. Driven by the UIKit recogniser layer
    /// (`SkyLabGestureView`); see `SkyLabGestureCoordinator`.
    @State private var sky = SkyLabGestureCoordinator()

    /// Only PROPER-named stars (Sirius, Betelgeuse…) get the POI label —
    /// like production. The Bayer / Flamsteed rest will get plain
    /// secondary text past max scale later; skipped for now. Computed
    /// ONCE (workableStars rebuilds ~9k EStars per access).
    private static let properNamedStars: [EStar] =
        StarDatabase.shared.workableStars.filter { $0.properName != nil }

    /// Off-screen drawing margin per edge (pt). The Canvas is rendered
    /// this much larger than the screen so a pan reveals drawn grid, not
    /// blank — see the framing note in `body`. Generous for the lab;
    /// tune (and add `.clipped()`) when this graduates to production.
    private let overdraw: CGFloat = 600

    var body: some View {
        GeometryReader { geo in
            // The canvas is rendered OVERSIZE — the screen plus an
            // `overdraw` margin on every edge — and centred. A SwiftUI
            // Canvas clips to its own frame, so a screen-sized one would
            // slide in blank at the trailing edge the instant the parent
            // transform pans it. Drawing the margin keeps grid in reserve
            // all around; nothing clips it because we never apply
            // `.clipped()` and a `.frame` doesn't clip overflow.
            let canvasSize = CGSize(width:  geo.size.width  + overdraw * 2,
                                    height: geo.size.height + overdraw * 2)
            // Centre = canvasSize/2, which (because the oversize content is
            // centred in the screen below) lands on the screen centre.
            let camera = SkyLabCamera(
                scale:     sky.scale,
                offset:    sky.offset,        // committed pan baked in → Canvas
                rotation:  sky.rotation,      //   draws centred + spun for the view
                size:      canvasSize,
                viewpoint: app.viewpoint,
                sidereal:  app.localSiderealOffset
            )

            // Live transform values from the coordinator (clamped).
            let effPinch  = sky.effPinch
            let liveScale = sky.liveScale
            let applied   = sky.applied

            ZStack {
                // `.equatable()` → these Canvases redraw only when the
                // committed camera changes (a settle / date / origin move),
                // NOT per gesture frame. Frozen + parent-transformed = the
                // whole point. The starfield is the stress test.
                SkyLabGridCanvas(camera: camera)
                    .equatable()
                // Horizon + twilight rings — native concentric circles
                // about the zenith, riding the parent transform.
                SkyLabHorizonCircles(camera: camera)
                SkyLabStarsCanvas(camera: camera, stars: app.sortedStars)
                    .equatable()
                // Curved cartographic labels — horizon rim + colures.
                // Canvas (per-glyph curve), frozen via .equatable().
                SkyLabCartographyLabels(camera:   camera,
                                        latitude: app.origin.latitude,
                                        date:     app.renderedObservationDate)
                    .equatable()
                // Tiered native labels — each object reveals at its
                // production zoom tier (see each overlay's gate):
                //   • favourite stars  — .followedStar  (badgeIn 70)
                //   • constellation names — tier ~190
                //   • proper-name stars — .namedStar    (badgeIn ~280)
                //   • Sun/Moon/planets  — bodies overlay (0 / 80)
                // Greek-letter stars: skipped for now.
                SkyLabConstellationLabelsOverlay(camera: camera,
                                                 pinch: effPinch,
                                                 scale: liveScale)
                SkyLabStarLabelsOverlay(camera: camera,
                                        stars: app.favouriteStars,
                                        pinch: effPinch,
                                        scale: liveScale,
                                        category: { .followedStar($0) })
                SkyLabStarLabelsOverlay(camera: camera,
                                        stars: Self.properNamedStars,
                                        pinch: effPinch,
                                        scale: liveScale,
                                        category: { .namedStar($0) })
                SkyLabBodiesOverlay(camera: camera,
                                    date:  app.renderedObservationDate,
                                    pinch: effPinch,
                                    scale: liveScale)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            // THE shared parent transform — scale + rotation about centre,
            // then the live translation. Committed values live in the
            // camera; only the live deltas (frozen Canvases ride along)
            // are here. Order matters: scale, rotate, translate.
            .scaleEffect(effPinch, anchor: .center)
            .rotationEffect(sky.liveRotation, anchor: .center)
            .offset(x: applied.width, y: applied.height)
            // Constrain the layout back to the screen (centres the oversize
            // content; overflow renders off-screen, ready for the pan).
            .frame(width: geo.size.width, height: geo.size.height)
            // UIKit recogniser layer on top (screen-sized, NOT transformed)
            // — pan / pinch / rotation / double-tap-hold-drag, driving `sky`.
            .overlay {
                SkyLabGestureView(coordinator: sky)
                    .onAppear {
                        sky.center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    .onChange(of: geo.size) {
                        sky.center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
            }
        }
        // The label's casing is `.systemBackground` — designed to knock
        // stars out from behind the glyphs on a DARK sky, not to be a
        // bright outline. Without a dark background (and dark scheme) the
        // casing is invisible and the label reads borderless. Give the lab
        // the production night sky so labels render as intended.
        .background(EArtist.shared.canvasBackground)
//        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }
}

#Preview {
    SkyLabView()
        .environment(EAppState())
}

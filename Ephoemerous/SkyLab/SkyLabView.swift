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
      // One timeline, production's `ECanvasSchedule`: ticks at 60fps ONLY
      // while an app origin/date transition is in flight (the Here / Now
      // animations), and parks at `.distantFuture` when idle — so the
      // freeze model is untouched at rest. Without it the Here slerp would
      // never advance and a Now date-rotation would stick mid-interpolation.
      TimelineView(clockSchedule) { timeline in
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

            // Selection selectors — which passive label to suppress / emphasise.
            let selectedStarID: UUID?  = { if case .star(let s) = sky.selection { return s.id };          return nil }()
            let selectedConsID: String? = { if case .constellation(let c) = sky.selection { return c.rawValue }; return nil }()

            // Myth tint per favourite constellation (for its solid lines).
            let favTints = Dictionary(uniqueKeysWithValues: app.favouriteConstellations.map { cons -> (EConstellation, Color) in
                let dec  = ConstellationLines.shared.labelAnchors[cons]?.dec.degrees ?? 0
                let kind = EArtist.shared.constellationKind(cons, decDegrees: dec,
                                                            observerLatitude: app.origin.latitude.degrees)
                return (cons, EArtist.shared.constellationGradient(kind: kind).top)
            })

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
                // Constellation stick-figures — frozen Canvas; favourites
                // stroke solid in their myth tint.
                SkyLabConstellationLinesCanvas(camera: camera, favouriteTints: favTints)
                    .equatable()
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
                                                 scale: liveScale,
                                                 rotation: sky.liveRotation,
                                                 selectedID: selectedConsID)
                SkyLabStarLabelsOverlay(camera: camera,
                                        stars: app.favouriteStars,
                                        pinch: effPinch,
                                        scale: liveScale,
                                        rotation: sky.liveRotation,
                                        category: { .followedStar($0) },
                                        selectedID: selectedStarID)
                // Favourite-star heart signal (always visible).
                SkyLabFavouritesOverlay(camera: camera,
                                        stars: app.favouriteStars,
                                        pinch: effPinch,
                                        rotation: sky.liveRotation)
                SkyLabStarLabelsOverlay(camera: camera,
                                        stars: Self.properNamedStars,
                                        pinch: effPinch,
                                        scale: liveScale,
                                        rotation: sky.liveRotation,
                                        category: { .namedStar($0) },
                                        selectedID: selectedStarID)
                SkyLabBodiesOverlay(camera: camera,
                                    date:  app.renderedObservationDate,
                                    pinch: effPinch,
                                    scale: liveScale,
                                    rotation: sky.liveRotation,
                                    selected: sky.selection)
                // Promoted label — the selected object, forced visible at
                // any zoom (topmost so it reads above the passive labels).
                SkyLabPromotedLabelOverlay(camera: camera,
                                           selection: sky.selection,
                                           date:  app.renderedObservationDate,
                                           pinch: effPinch,
                                           rotation: sky.liveRotation)
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
                        sky.onTap  = makeTapHandler()
                    }
                    .onChange(of: geo.size) {
                        sky.center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
            }
        }
        // Per-frame clock — drives the app's origin/date transitions (the
        // Here / Now moves) while one is live; draws nothing. A `.background`
        // so it sits behind everything and re-runs each timeline tick.
        .background {
            Canvas { _, size in
                app.advanceCanvasClock(to: timeline.date.timeIntervalSinceReferenceDate,
                                       canvasSize: size)
            }
            .allowsHitTesting(false)
        }
        // The label's casing is `.systemBackground` — designed to knock
        // stars out from behind the glyphs on a DARK sky, not to be a
        // bright outline. Without a dark background (and dark scheme) the
        // casing is invisible and the label reads borderless. Give the lab
        // the production night sky so labels render as intended.
        .background(EArtist.shared.canvasBackground)
//        .preferredColorScheme(.dark)
        // Production toolbar — Here / Now reset chips + location / date
        // pills. It acts on the shared EAppState the SkyLab camera reads,
        // so the sky follows; the clock above plays the transitions.
        .overlay(alignment: .top) {
            VStack {
                MainToolbar()
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top,        64)
        }
        .ignoresSafeArea()
        // The pills raise these inline editors, same as production MainView.
        .sheet(isPresented: Bindable(app).isShowingLocationPicker) {
            LocationPickerPanel()
                .presentationDetents([.height(300)])
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: Bindable(app).isShowingDatePicker) {
            DatePickerPanel()
                .presentationDetents([.height(250)])
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
        }
      } //: TimelineView
    }

    /// Clock gate — animate only while the observer is moving (Here) or the
    /// date is rotating (Now); otherwise park so the freeze model holds.
    private var clockSchedule: ECanvasSchedule {
        ECanvasSchedule(isAnimating: app._dateTransition   != nil
                                  || app._originTransition != nil)
    }

    // MARK: - Tap → select + comfort-zone pan

    /// Builds the tap handler stored on the coordinator. The closure
    /// captures the live `app` (a reference) and rebuilds the camera from
    /// the coordinator's CURRENT committed state at tap time, so it always
    /// hit-tests against what's on screen.
    private func makeTapHandler() -> (CGPoint) -> Void {
        let overdraw = self.overdraw
        let app      = self.app
        return { [weak sky] loc in
            guard let sky else { return }
            // Only act at rest — otherwise interrupt the in-flight fling
            // (so the tap stops the slide) and let the next tap select.
            guard sky.isResting else { sky.settleNow(); return }

            // Screen + canvas geometry, reconstructed from the coordinator.
            let geoSize = CGSize(width: sky.center.x * 2, height: sky.center.y * 2)
            guard geoSize.width > 0, geoSize.height > 0 else { return }
            let canvasSize = CGSize(width:  geoSize.width  + overdraw * 2,
                                    height: geoSize.height + overdraw * 2)
            let camera = SkyLabCamera(scale:     sky.scale,
                                      offset:    sky.offset,
                                      rotation:  sky.rotation,
                                      size:      canvasSize,
                                      viewpoint: app.viewpoint,
                                      sidereal:  app.localSiderealOffset)

            // Only LABELLED objects are tappable — respect the tiers, so the
            // tap target set grows exactly as the labels reveal with zoom.
            // Gathers every kind (star / sun / moon / planet / constellation)
            // gated by the SAME threshold its label overlay obeys, projects
            // each, and picks the nearest within the touch radius. Canvas
            // points are oversized → subtract `overdraw` for screen space.
            let scale = sky.scale
            let date  = app.renderedObservationDate
            let a     = EArtist.shared

            var cands: [(obj: ESkyObject, screen: CGPoint)] = []
            func consider(_ obj: ESkyObject, gate: Bool) {
                guard gate, let cp = SkyLabObjects.screen(obj, camera: camera, date: date) else { return }
                cands.append((obj, CGPoint(x: cp.x - overdraw, y: cp.y - overdraw)))
            }

            // Stars — each gated by its own badge tier (favourites at 70,
            // proper-named deeper, per-star by magnitude). A favourite that's
            // also proper-named is tested once, as followed.
            let favIDs = Set(app.favouriteStars.map(\.id))
            for star in app.favouriteStars {
                consider(.star(star), gate: scale >= a.poiStyle(for: .followedStar(star)).badgeIn)
            }
            for star in Self.properNamedStars where !favIDs.contains(star.id) {
                consider(.star(star), gate: scale >= a.poiStyle(for: .namedStar(star)).badgeIn)
            }

            // Solar-system bodies — Sun / Moon always (badgeIn 0), planets
            // past their badge tier.
            consider(.sun,  gate: true)
            consider(.moon, gate: true)
            for (planet, _, _, _) in EPlanetPosition.allVectors(for: date, siderealOffset: camera.sidereal) {
                consider(.planet(planet), gate: scale >= a.poiStyle(for: .planet(planet)).badgeIn)
            }

            // Constellation names — tappable once the name tier reveals.
            let consTextIn = a.poiStyle(for: .constellation(.myth(.none))).textIn
            if scale >= consTextIn {
                for (cons, _) in ConstellationLines.shared.labelAnchors {
                    consider(.constellation(cons), gate: true)
                }
            }

            let tapRadius: CGFloat = 30
            var best: (obj: ESkyObject, dist: CGFloat, screen: CGPoint)? = nil
            for (obj, s) in cands {
                let d = hypot(s.x - loc.x, s.y - loc.y)
                if d <= tapRadius, best == nil || d < best!.dist {
                    best = (obj, d, s)
                }
            }
            // Tapped empty sky → clear (animated demotion).
            guard let hit = best else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    sky.selection = nil
                }
                return
            }

            // Promote: springs the label in (and cross-fades if switching).
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                sky.selection = hit.obj
            }

            // Comfort zone: upper-third focus, 100pt no-pan radius. Inside →
            // stay put; outside → pan just to the circle's edge (minimal
            // motion), mirroring production's `panFocus`.
            let focus = CGPoint(x: geoSize.width / 2, y: geoSize.height / 3)
            let dx = hit.screen.x - focus.x
            let dy = hit.screen.y - focus.y
            let dist = hypot(dx, dy)
            let comfortRadius: CGFloat = 100
            guard dist > comfortRadius else { return }

            let k    = comfortRadius / dist
            let edge = CGPoint(x: hit.screen.x - dx * k, y: hit.screen.y - dy * k)
            sky.focusPan(dragTarget: CGSize(width:  edge.x - hit.screen.x,
                                            height: edge.y - hit.screen.y))
        }
    }
}

#Preview {
    SkyLabView()
        .environment(EAppState())
}

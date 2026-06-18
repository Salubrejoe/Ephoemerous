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
struct MainView😇: View {

    @Environment(EAppState.self) private var app

    /// Camera + gesture engine — committed camera (scale/offset/rotation)
    /// frozen during a gesture, live deltas drive the parent transform,
    /// folded once on release. Driven by the UIKit recogniser layer
    /// (`MainGestureCoordinator`); see `MainGestureCoordinator`.
    @State private var sky = MainGestureCoordinator()

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

    /// Detail place-card detent — pinned so the sheet opens at the third
    /// (not the smallest member of the set) and can fold to a header-only
    /// stop, Apple-Maps style. Mirrors production MainView.
    @State private var detailDetent: PresentationDetent = .fraction(1.0 / 3.5)
    private let detailHeaderDetent: PresentationDetent = .height(70)

    var body: some View {
      // One timeline, production's `ECanvasSchedule`: ticks at 60fps ONLY
      // while an app origin/date transition is in flight (the Here / Now
      // animations), and parks at `.distantFuture` when idle — so the
      // freeze model is untouched at rest. Without it the Here slerp would
      // never advance and a Now date-rotation would stick mid-interpolation.
      ZStack {
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

            // Compass (heading-up) mode: the device heading OWNS the
            // rotation. The committed `sky.rotation` is replaced by the
            // smoothed heading (`renderedRotation` — positions only, so
            // labels stay upright), and the live rotation gesture is ignored
            // (`liveRot` → 0). The clock ticks continuously while it's on
            // (see `clockSchedule`) so the heading low-pass integrates each
            // frame; on exit the heading is frozen back into `sky.rotation`
            // (see `onChange`) so nothing jumps.
            let inCompass      = app.compassMode
            // NEGATED: SkyLabCamera.screen rotates AFTER the y-flip, whereas
            // production's toScreen (which `renderedRotation` is tuned for)
            // rotates BEFORE it — a y-flip inverts rotation handedness. Without
            // the negation, heading-up spins the wrong way (face east → west up).
            let cameraRotation = inCompass ? .radians(-app.renderedRotation.radians)
                                           : sky.rotation
            let liveRot        = inCompass ? .zero : sky.liveRotation

            // Centre = canvasSize/2, which (because the oversize content is
            // centred in the screen below) lands on the screen centre.
            let camera = SkyCamera(
                scale:     sky.scale,
                offset:    sky.offset,        // committed pan baked in → Canvas
                rotation:  cameraRotation,    //   draws centred + spun for the view
                size:      canvasSize,
                viewpoint: app.viewpoint,
                sidereal:  app.localSiderealOffset
            )

            // Live transform values from the coordinator (clamped).
            let effPinch  = sky.effPinch
            let liveScale = sky.liveScale
            let applied   = sky.applied

            // Selection selectors — which passive label to suppress /
            // emphasise. Source of truth is the production `detailDestination`
            // (also drives the detail sheet), so tap-select, the sheet's X,
            // and a swipe-away all stay in lockstep.
            let selection = app.detailDestination
            let selectedStarID: UUID?  = { if case .star(let s) = selection { return s.id };          return nil }()
            let selectedConsID: String? = { if case .constellation(let c) = selection { return c.rawValue }; return nil }()

            // A favourite that's also proper-named would otherwise draw BOTH
            // a `.followedStar` and a `.namedStar` badge — exclude favourites
            // from the named overlay so each star gets exactly one label.
            let favIDs = Set(app.favouriteStars.map(\.id))
            let namedOnly = Self.properNamedStars.filter { !favIDs.contains($0.id) }

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
                CelestialGridCanvas(camera: camera)
                    .equatable()
                
                // "You are here" — aim cone + globe puck at the zenith,
                // gated on being at the device location.
                PuckAndConeOverlay(camera: camera, pinch: effPinch)
                
                // Horizon + twilight rings — native concentric circles
                // about the zenith, riding the parent transform.
                EarthGridOverlay(camera: camera)
                
                // Constellation stick-figures — frozen Canvas; favourites
                // stroke solid in their myth tint.
                ConstellationLinesCanvas(camera: camera, favouriteTints: favTints)
                    .equatable()
                
                StarsCanvas(camera: camera, stars: app.sortedStars)
                    .equatable()
                
                // Tier-0 spectral pentagon dots for proper-named stars —
                // appear past namedStarDotIn, crossfade into the badge.
                NamedStarDotsCanvas(camera: camera,
                                          stars: namedOnly,
                                          scale: liveScale,
                                          selectedID: selectedStarID)
                    .equatable()
               
                // Curved cartographic labels — horizon rim + colures.
                // Canvas (per-glyph curve), frozen via .equatable().
                CartographyLabels(camera:   camera,
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
                ConstellationLabels(camera: camera,
                                                 pinch: effPinch,
                                                 scale: liveScale,
                                                 rotation: liveRot,
                                                 selectedID: selectedConsID)
                StarLabels(camera: camera,
                                        stars: app.favouriteStars,
                                        pinch: effPinch,
                                        scale: liveScale,
                                        rotation: liveRot,
                                        category: { .followedStar($0) },
                                        selectedID: selectedStarID)
                // Favourite-star heart signal (always visible, except the
                // selected one — the promoted pin stands in for it).
                FavouriteHeart(camera: camera,
                                        stars: app.favouriteStars,
                                        pinch: effPinch,
                                        rotation: liveRot,
                                        selectedID: selectedStarID)
                StarLabels(camera: camera,
                                        stars: namedOnly,
                                        pinch: effPinch,
                                        scale: liveScale,
                                        rotation: liveRot,
                                        category: { .namedStar($0) },
                                        selectedID: selectedStarID)
                SolarSystemLabels(camera: camera,
                                    date:  app.renderedObservationDate,
                                    pinch: effPinch,
                                    scale: liveScale,
                                    rotation: liveRot,
                                    selected: selection)
                // Promoted label — the selected object, forced visible at
                // any zoom (topmost so it reads above the passive labels).
                PromotedLabel(camera: camera,
                                           selection: selection,
                                           date:  app.renderedObservationDate,
                                           pinch: effPinch,
                                           rotation: liveRot)
            }
            
            .frame(width: canvasSize.width, height: canvasSize.height)
            // THE shared parent transform — scale + rotation about centre,
            // then the live translation. Committed values live in the
            // camera; only the live deltas (frozen Canvases ride along)
            // are here. Order matters: scale, rotate, translate.
            .scaleEffect(effPinch, anchor: .center)
            .rotationEffect(liveRot, anchor: .center)
            .offset(x: applied.width, y: applied.height)
            // Constrain the layout back to the screen (centres the oversize
            // content; overflow renders off-screen, ready for the pan).
            .frame(width: geo.size.width, height: geo.size.height)
            // UIKit recogniser layer on top (screen-sized, NOT transformed)
            // — pan / pinch / rotation / double-tap-hold-drag, driving `sky`.
            .overlay {
                MainGestureView(coordinator: sky)
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
        } //: TimelineView closure (only the clock Canvas needs `timeline`)
        } //: ZStack — the sheets + alert attach HERE, a plain stable
        //  container like production's root ZStack, NOT the TimelineView
        //  (whose content churns on schedule/state changes and was
        //  disrupting the alert ↔ persistent-search-sheet presentation).
        // The label's casing is `.systemBackground` — designed to knock
        // stars out from behind the glyphs on a DARK sky, not to be a
        // bright outline. Without a dark background (and dark scheme) the
        // casing is invisible and the label reads borderless. Give the lab
        // the production night sky so labels render as intended.
        .background(
            ZStack {
                EArtist.shared.canvasBackground
                
                VStack {
                    Rectangle()
                        .fill(EArtist.shared.canvasBackground)
                        .hueRotation(.degrees(5))
                        .frame(height: 200)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(EArtist.shared.canvasBackground)
                        .hueRotation(.degrees(-5))
                        .frame(height: 200)
                }
                .blur(radius: 2)
            }
        )
        // Production toolbar — Here / Now reset chips + location / date
        // pills. It acts on the shared EAppState the SkyLab camera reads,
        // so the sky follows; the clock above plays the transitions.
        .overlay(alignment: .top) {
            VStack {
                MainToolbar()
                HStack {
                    Spacer()
                    CompassButton()
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top,        64)
        }
        
        .ignoresSafeArea()
        
//        .alert("Return to your location?",
//               isPresented: Bindable(app)._compassReturnHomePrompt) {
//            Button("Cancel", role: .cancel) { }
//            Button("Switch to Here") { app.confirmReturnHomeAndEngageCompass() }
//        } message: {
//            Text("Compass mode orients the sky from where you're standing. Move the map back to your location?")
//        }
        // Toggling compass mode away from Here needs the observer back at the
        // device location first; confirm before snapping. Declared as the
        // FIRST (innermost) presentation modifier — BEFORE the sheets — to
        // mirror production MainView: an alert applied AFTER the sheets fights
        // the persistent search sheet's presentation (the alert flashed and
        // killed the search bar). Mirrors production MainView's order.
        
        .fontDesign(.rounded)
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
        // Detail place card — item-bound to the selection. The canvas
        // stays interactive behind it (taps deselect / reselect); two
        // Apple-Maps detents, header-only fold + the default third, plus
        // `.large` for the constellation roster. Search / myth deliberately
        // left out for now. Mirrors production MainView's detail host.
        .sheet(item: Bindable(app).detailDestination) { obj in
            DetailHost(obj: obj)
                .id(obj.id)
                .environment(\.detailCollapsed, detailDetent == detailHeaderDetent)
                .animation(.snappy(duration: 0.28), value: detailDetent)
                .presentationDetents([detailHeaderDetent, .fraction(1.0 / 3.0), .large],
                                     selection: $detailDetent)
                .interactiveDismissDisabled()
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.visible)
                .onAppear { detailDetent = .fraction(1.0 / 3.0) }
        }
        // Persistent Apple-Maps search sheet — always up at its bar-only
        // detent whenever nothing else owns the bottom slot. Selecting an
        // object sets `detailDestination`, which flips `searchPresented`
        // false → search yields to the detail sheet. Verbatim production.
        .sheet(isPresented: searchPresented) { SearchSheet() }
        // Any selection (canvas tap OR search pick) glides into the comfort
        // zone — one place, so the two paths behave identically.
        .onChange(of: app.detailDestination) { _, obj in
            if let obj { panIntoComfortZone(obj) }
        }
        // Leaving compass mode → freeze the live heading into the committed
        // `sky.rotation`, so the camera (which now reads `sky.rotation`
        // again) shows the same orientation the heading left — no jump.
        // Declared BEFORE the reset observer so the freeze lands first when
        // the exit IS the rose's reset-to-north (freeze heading, then spin).
        .onChange(of: app.compassMode) { was, now in
            // Negated to match `cameraRotation`'s flip (see above) so the
            // committed rotation picks up exactly where the heading left.
            if was, !now {
                sky.rotation = .radians(-app.canvasRotation.radians)
            }
        }
        // Mirror the SkyLab's committed + live rotation into the app rotation
        // the compass rose reads (`renderedRotation`), so the rose appears —
        // and its dial tracks — whenever the user twists the canvas, not only
        // in compass mode. Negated to match the camera's y-flip handedness so
        // `-renderedRotation` equals the on-screen rotation in BOTH modes.
        .onChange(of: sky.rotation)     { _, _ in mirrorRotationToRose() }
        .onChange(of: sky.liveRotation) { _, _ in mirrorRotationToRose() }
        // The compass rose's reset-to-north (`resetRotationToNorth` →
        // `animateRotation`, only ever targeting zero). Spring the committed
        // rotation to north — from the just-frozen heading if we left
        // compass, else from where a manual twist left it.
        .onChange(of: app._rotationTransition?.to) { _, to in
            guard let to, to == .zero else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                sky.rotation = .zero
            }
        }
    }

    /// Search is up exactly when nothing else owns the bottom slot — no
    /// selection, no myth, neither picker, and not mid sheet-swap. Read-only
    /// (a no-op setter); `interactiveDismissDisabled` blocks manual dismiss,
    /// so only a selection / editor hides it. Mirrors production MainView.
    private var searchPresented: Binding<Bool> {
        Binding(
            get: {
                app.detailDestination == nil
                    && app.mythDestination == nil
                    && !app.isShowingLocationPicker
                    && !app.isShowingDatePicker
                    && !app._sheetSwapping
            },
            set: { _ in }
        )
    }

    /// Clock gate — tick while the observer is moving (Here), the date is
    /// rotating (Now), OR compass mode is following the heading; otherwise
    /// park so the freeze model holds.
    private var clockSchedule: ECanvasSchedule {
        ECanvasSchedule(isAnimating: app._dateTransition     != nil
                                  || app._originTransition   != nil
                                  || app._rotationTransition != nil
                                  || app.compassMode)
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
            let camera = SkyCamera(scale:     sky.scale,
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
            // Tapped empty sky → deselect (animated demotion + sheet
            // dismiss). Only act if something is selected, so an idle tap on
            // empty sky doesn't thrash state.
            guard let hit = best else {
                if app.detailDestination != nil {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        app.detailDestination = nil
                    }
                }
                return
            }

            // Promote: springs the label in + raises the detail sheet. A
            // picker owns the bottom slot first — close it so the sheet can
            // take over. The comfort-zone pan is driven by `onChange(of:
            // detailDestination)` so a search pick pans too.
            app.isShowingLocationPicker = false
            app.isShowingDatePicker     = false

            let promote = { (obj: ESkyObject) in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    app.detailDestination = obj
                }
            }
            // A DIFFERENT card is already up → tear it down and re-present
            // after a beat (production's `sheetSwapDelay`). Swapping the
            // sheet's item in place keeps the live presentation, and the new
            // card lands at the wrong (large) detent instead of the third;
            // `_sheetSwapping` hides search across the gap.
            if let current = app.detailDestination, current.id != hit.obj.id {
                app._sheetSwapping    = true
                app.detailDestination = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    app._sheetSwapping = false
                    promote(hit.obj)
                }
            } else {
                promote(hit.obj)
            }
        }
    }

    /// Reflect the SkyLab's rotation into `app.canvasRotation` so the rose
    /// (which reads `renderedRotation`) shows up when the canvas is twisted.
    /// Skipped in compass mode — there the heading owns `renderedRotation`.
    private func mirrorRotationToRose() {
        guard !app.compassMode else { return }
        let mirrored = Angle.radians(-(sky.rotation.radians + sky.liveRotation.radians))
        if app.canvasRotation != mirrored { app.canvasRotation = mirrored }
    }

    // MARK: - Comfort-zone pan (any selection)

    /// Pan the selected object into the comfort zone — upper-third focus,
    /// 100pt no-pan radius; outside it, glide just to the circle's edge
    /// (minimal motion), mirroring production's `panFocus`. Driven off the
    /// selection (not the tap) so a SEARCH pick pans the same as a canvas
    /// tap. No-op if already comfy, mid-gesture, or the object is on the
    /// back of the sphere (can't pan-only to it — a slew would be needed).
    private func panIntoComfortZone(_ obj: ESkyObject) {
        guard sky.isResting else { return }
        let geoSize = CGSize(width: sky.center.x * 2, height: sky.center.y * 2)
        guard geoSize.width > 0, geoSize.height > 0 else { return }
        let canvasSize = CGSize(width:  geoSize.width  + overdraw * 2,
                                height: geoSize.height + overdraw * 2)
        let camera = SkyCamera(scale:     sky.scale,
                                  offset:    sky.offset,
                                  rotation:  sky.rotation,
                                  size:      canvasSize,
                                  viewpoint: app.viewpoint,
                                  sidereal:  app.localSiderealOffset)
        guard let cp = SkyLabObjects.screen(obj, camera: camera,
                                            date: app.renderedObservationDate) else { return }
        let objScreen = CGPoint(x: cp.x - overdraw, y: cp.y - overdraw)
        let focus = CGPoint(x: geoSize.width / 2, y: geoSize.height / 3)
        let dx = objScreen.x - focus.x
        let dy = objScreen.y - focus.y
        let dist = hypot(dx, dy)
        let comfortRadius: CGFloat = 100
        guard dist > comfortRadius else { return }

        // Land the object on the NEAREST point of the comfort circle —
        // `focus + R·û` — so it moves by `dist - R`. (Production's panFocus
        // instead nudges `R` toward the focus, which lands a near canvas-tap
        // inside the zone but barely shifts a FAR list pick — the "not enough
        // to move" bug.) Minimal motion for a near tap, as much as needed
        // for a far one.
        let k    = comfortRadius / dist
        let edge = CGPoint(x: focus.x + dx * k, y: focus.y + dy * k)
        sky.focusPan(dragTarget: CGSize(width:  edge.x - objScreen.x,
                                        height: edge.y - objScreen.y))
    }
}

#Preview {
    MainView()
        .environment(EAppState())
}

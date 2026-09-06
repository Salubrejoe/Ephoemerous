import SwiftUI
import UIKit

// MARK: - MainView
// The app's root: the sky, everything drawn on it, and the chrome over it.
//
// THE SYNC MODEL, which the whole canvas is built around:
//   • Every layer renders at the camera's COMMITTED (resting) transform.
//   • A live gesture writes only transient deltas, which drive ONE
//     `.scaleEffect` + `.rotationEffect` + `.offset` on the stack holding
//     every child. A parent transform lands on all of them in the same
//     CoreAnimation commit, so frozen Canvases and native overlays move as
//     one and cannot desync — no per-frame reprojection, no second clock.
//   • On release the delta folds into the committed camera: one
//     reconciliation render at the new position.
//
// This file keeps only the composition. The pieces live beside it:
//   SkyFrame          — camera + live transform + per-layer star ownership
//   SkyLayerStack     — the layers themselves, back to front
//   SkyChrome         — the floating controls
//   MainView+Selection — tap hit-testing and the comfort-zone pan
struct MainView: View {

    // A few members below are internal rather than private: the selection
    // logic lives in `MainView+Selection.swift`, and `private` in Swift is
    // file-scoped, so a sibling extension cannot see it.


    @Environment(AppState.self) var app

    /// Camera + gesture engine — committed camera (scale/offset/rotation)
    /// frozen during a gesture, live deltas drive the parent transform,
    /// folded once on release. Driven by the UIKit recogniser layer
    /// (`MainGestureCoordinator`); see `MainGestureCoordinator`.
    @State var sky = MainGestureCoordinator()


    /// Off-screen drawing margin per edge (pt). The Canvas is rendered
    /// this much larger than the screen so a pan reveals drawn grid, not
    /// blank — see the framing note in `body`. Generous for the lab;
    /// tune (and add `.clipped()`) when this graduates to production.
    let overdraw: CGFloat = 600

    /// Detail place-card detent — pinned so the sheet opens at the third
    /// (not the smallest member of the set) and can fold to a header-only
    /// stop, Apple-Maps style. Mirrors production MainView.
    @State private var detailDetent: PresentationDetent = .fraction(1.0 / 4.0)
    private let detailHeaderDetent: PresentationDetent = .height(70)

    /// Compass-mode framing progress, eased 0→1 on toggle (see the
    /// `compassMode` onChange). 0 = the committed `sky` view; 1 = the full
    /// heading-up framing (puck low, horizon high). Interpolating the camera
    /// by this — rather than flipping it — turns the entry / exit into a
    /// smooth zoom instead of a snap.
    @State private var compassEngage: Double = 0

    /// Visible screen size (NOT the oversized canvas). Kept in sync with the
    /// `GeometryReader` so the `compassMode` exit handler can recompute the
    /// framing to freeze it into the committed camera.
    @State private var viewSize: CGSize = .zero

    /// iPad / regular width takes the Apple-Maps treatment: ONE floating
    /// card in the bottom-LEADING corner instead of a bottom sheet. Keyed
    /// on the size class, NOT the idiom — an iPad in Slide Over or a
    /// narrow Stage Manager window is compact, and the sheet is genuinely
    /// the right answer there.
    @Environment(\.horizontalSizeClass) private var hSize
    private var isRegular: Bool { hSize == .regular }

    /// The floating panel's rest position (regular width only). Owned
    /// here, not by the content, because ONE panel hosts both search and
    /// the detail card and the stage has to survive the swap.
    @State private var panelStage: PanelStage = .bar


    /// Seed / retune the camera's home + zoom floor from the visible screen
    /// size. The coordinator's built-in 90 approximates an iPhone; on iPad
    /// the horizon launched small until a NorthOUT round-trip happened to
    /// reseed it (the `isNorthOut` onChange). NorthOUT frames itself, so
    /// it's left alone; and only a camera still resting at its old home is
    /// moved — a user zoom survives a resize.
    private func seedCameraHome(for size: CGSize) {
        guard !app.isNorthOut else { return }
        let wasHome = abs(sky.scale - sky.defaultScale) < 0.5
        let target  = app.defaultScale(for: size)
        sky.minScale     = northInMinScale(defaultScale: target)
        sky.defaultScale = target
        if wasHome { sky.scale = target }
    }

    /// NorthIN zoom floor. iPhone: home itself — no pulling back past the
    /// fit-to-height default. iPad: opened DOWN to where a favourite
    /// star's name label is still FULLY revealed — `textIn` plus the 18%
    /// fade band (see `POILabelView.tierReveal`) — so the wide canvas can
    /// zoom out further without the favourites going mute.
    private func northInMinScale(defaultScale target: CGFloat) -> CGFloat {
        guard isPad else { return target }
        let nameIn = Artist.shared.followedStarTier.textIn * 1.0
        return Swift.min(target, CGFloat(nameIn))
    }

    /// iPad relocates the camera cluster to the top-trailing corner —
    /// the wide canvas leaves the bottom-trailing slot marooned mid-air
    /// above the full-width search sheet.
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Camera scale/offset captured at the start of a NorthIN↔NorthOUT morph.
    /// The camera glides from these to the committed `sky` target across the
    /// morph (see `perspectiveMorphProgress`), so the reframe animates on the
    /// Canvas in lockstep with the projection instead of snapping.
    @State private var morphScaleFrom:  CGFloat = 0
    @State private var morphOffsetFrom: CGSize  = .zero
    
    private var gradient: RadialGradient {
        let backColor   = Artist.shared.canvasBackground
        let colorEdge   = app.isNorthOut ? backColor : .black.opacity(0.01)
        
        return RadialGradient(stops: [
            .init(color: backColor, location: 0.0),
            .init(color: colorEdge, location: 1.0),
        ], center: .center, startRadius: app.scale*3, endRadius: app.canvasSize.height)
    }

    var body: some View {
      // One timeline, production's `CanvasSchedule`: ticks at 60fps ONLY
      // while an app origin/date transition is in flight (the Here / Now
      // animations), and parks at `.distantFuture` when idle — so the
      // freeze model is untouched at rest. Without it the Here slerp would
      // never advance and a Now date-rotation would stick mid-interpolation.
      ZStack {
      TimelineView(clockSchedule) { timeline in
        GeometryReader { geo in
            // One value carries the whole frame — camera, live transform,
            // and which layer owns which star. See `SkyFrame`.
            let frame = SkyFrame(app: app,
                                 sky: sky,
                                 geoSize: geo.size,
                                 overdraw: overdraw,
                                 compassEngage: compassEngage,
                                 morphScaleFrom: morphScaleFrom,
                                 morphOffsetFrom: morphOffsetFrom)

            SkyLayerStack(frame: frame)
            
            .frame(width: frame.canvasSize.width, height: frame.canvasSize.height)
            // THE shared parent transform — scale + rotation about centre,
            // then the live translation. Committed values live in the
            // camera; only the live deltas (frozen Canvases ride along)
            // are here. Order matters: scale, rotate, translate.
            .scaleEffect(frame.effPinch, anchor: .center)
            .rotationEffect(frame.liveRot, anchor: .center)
            .offset(x: frame.applied.width, y: frame.applied.height)
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
                        viewSize   = geo.size
                        seedCameraHome(for: geo.size)
                        // Grabbing the canvas drops compass mode (heading no
                        // longer owns the view) — but the zoom/framing stays
                        // put (frozen in the `compassMode` exit handler), so
                        // the gesture just continues from where compass left
                        // the sky.
                        sky.onGestureStart = {
                            if app.compassMode { app.disengageCompassMode() }
                        }
                    }
                    .onChange(of: geo.size) {
                        sky.center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        viewSize   = geo.size
                        seedCameraHome(for: geo.size)
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
        gradient
      )
        .preferredColorScheme(.dark)
        .modifier(SkyChrome(viewSize: viewSize))
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
        .overlay {                                    // was .overlay(alignment: .bottom)
            if app.isShowingDatePicker {
                DatePickerPanel()
                    .ignoresSafeArea()
                    .transition(.opacity)             // was move-from-bottom
            }
        }
        .onChange(of: app.isShowingDatePicker) { _, showing in
            // Camera home → the ring sits on the horizon. The picker pulls
            // it IN as well, so the crown clears the Here/Now capsule and
            // the control row rather than running off both.
            sky.glide(to: showing ? app.datePickerScale(screenSize: viewSize)
                                  : sky.defaultScale)
        }
        .fontDesign(.rounded)
        // The pills raise these inline editors, same as production MainView.
        .sheet(isPresented: Bindable(app).isShowingLocationPicker) {
            LocationPickerPanel()
                .presentationDetents([.height(300)])
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
        }
        // The date crown floats FREE — no sheet. Sheets are for content
        // (the location picker carries a map); the crown is a pure
        // instrument standing on the sky, which stays touchable around it.
        // The search sheet already yields while a picker is open
        // (`searchPresented`), so the bottom slot is clear.
//        .overlay(alignment: .bottom) {
//            if app.isShowingDatePicker {
//                DatePickerPanel()
//                    // Clear the home indicator. ▼ TWEAK the float here ▼
//                    .transition(.move(edge: .bottom).combined(with: .opacity))
//            }
//        }
        // Detail place card — item-bound to the selection. The canvas
        // stays interactive behind it (taps deselect / reselect); two
        // Apple-Maps detents, header-only fold + the default third, plus
        // `.large` for the constellation roster. Search / myth deliberately
        // left out for now. Mirrors production MainView's detail host.
        .sheet(item: detailSheetItem) { obj in
            DetailHost(obj: obj)
                .id(obj.id)
                .environment(\.detailCollapsed, detailDetent == detailHeaderDetent)
                .animation(.snappy(duration: 0.28), value: detailDetent)
                .presentationDetents([detailHeaderDetent, .fraction(1.0 / 3.0), .large],
                                     selection: $detailDetent)
                .interactiveDismissDisabled()
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.visible)
                .tracksBottomSheet()
                .onAppear { detailDetent = .fraction(1.0 / 3.0) }
        }
        // Persistent Apple-Maps search sheet — always up at its bar-only
        // detent whenever nothing else owns the bottom slot. Selecting an
        // object sets `detailDestination`, which flips `searchPresented`
        // false → search yields to the detail sheet. Verbatim production.
        .sheet(isPresented: searchSheetPresented) { SearchSheet().tracksBottomSheet() }
        // Regular width: the same two surfaces, placed rather than
        // presented, sharing ONE card in the bottom-leading corner.
        .overlay(alignment: .bottomLeading) {
            // Same rule the sheet obeys: the panel yields while a scene
            // editor owns the screen. `searchPresented` already excludes
            // both pickers; the panel was ignoring it and left a search bar
            // floating over the date crown.
            if isRegular, app.detailDestination != nil || searchPresented.wrappedValue {
                FloatingPanel(stage: $panelStage,
                              available: viewSize.height,
                              showsDragBand: app.detailDestination != nil) {
                    if let obj = app.detailDestination {
                        DetailHost(obj: obj, stacked: false)
                            .id(obj.id)
                            .environment(\.detailCollapsed, panelStage == .bar)
                            .environment(\.detailInPanel,   true)
                    } else {
                        SearchSheet(panelStage: $panelStage)
                    }
                }
                // The card is BOTTOM-anchored, so SwiftUI's keyboard
                // avoidance lifted the whole thing by the keyboard's
                // height — and an open card plus a keyboard is taller than
                // the screen, which is how it ended up off the top. Opting
                // out leaves it where it is and lets the keyboard slide
                // over its lower half; the search field lives at the card's
                // TOP, and focusing raises the stage to `.large`, so the
                // field and the first results stay clear.
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .transition(.opacity)
            }
        }
        // Any selection (canvas tap OR search pick) glides into the comfort
        // zone — one place, so the two paths behave identically.
        .onChange(of: app.detailDestination) { _, obj in
            if let obj { panIntoComfortZone(obj) }
            // The card arriving in the panel should be readable without a
            // drag; leaving it parks the panel back at the search bar.
            if isRegular {
                withAnimation(.snappy(duration: 0.32)) {
                    panelStage = obj == nil ? .bar : .medium
                }
            }
        }
        // Leaving compass mode → freeze the live heading into the committed
        // `sky.rotation`, so the camera (which now reads `sky.rotation`
        // again) shows the same orientation the heading left — no jump.
        // Declared BEFORE the reset observer so the freeze lands first when
        // the exit IS the rose's reset-to-north (freeze heading, then spin).
        .onChange(of: app.compassMode) { was, now in
            if !was, now {
                // Entering — glide the framing in (see `compassEngage`).
                withAnimation(.easeInOut(duration: 0.6)) { compassEngage = 1 }
            } else if was, !now {
                // Leaving — FREEZE the framed view (rotation + zoom) into the
                // committed `sky` camera so exiting KEEPS the preset you're on
                // instead of springing back to the pre-compass zoom. No exit
                // glide: the sky stays exactly where it is and touch resumes.
                //
                // Rotation: negated to match `cameraRotation`'s flip so the
                // committed rotation picks up where the heading left.
                sky.rotation = .radians(-app.canvasRotation.radians)
                // Nothing to bake back in: compass no longer touches zoom or
                // offset, so `sky` already holds the view on screen.
                compassEngage = 0
            }
        }
        // Toggling NorthOUT reframes the camera: the pole-centred view is
        // framed to the tropics, so it wants a wider default AND a lower zoom
        // floor than the observer view. Retune the coordinator's bounds so the
        // wide scale actually holds (otherwise the rubber-band snaps it back to
        // the observer floor), then ease scale + recentre. The projection
        // switches instantly at the flag flip; the zoom settles around it.
        .onChange(of: app.isNorthOut) { _, northOut in
            // Capture where the camera is NOW, commit the destination framing
            // to `sky`, then hand the transition to the canvas clock. The
            // camera glides `morphScaleFrom → sky.scale` by the morph progress
            // (see the camera build) while the eye slerps — grid, labels and
            // horizon all reproject each tick and move together.
            morphScaleFrom  = sky.scale
            morphOffsetFrom = sky.offset
            let target = northOut ? app.northOutDefaultScale : app.defaultScale
            sky.minScale     = northOut ? target : northInMinScale(defaultScale: target)
            sky.defaultScale = target
            sky.scale        = target
            sky.offset       = .zero
            app.animatePerspectiveMorph(to: northOut ? 1 : 0)
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
    /// The search SHEET is compact-width only — in regular width the same
    /// content lives in the floating panel, so the sheet must not present
    /// as well or the app would carry two search fields.
    private var searchSheetPresented: Binding<Bool> {
        Binding(get: { !isRegular && searchPresented.wrappedValue },
                set: { _ in })
    }

    /// Likewise the detail sheet: in regular width the panel hosts the
    /// place card, so the sheet host is starved of its item. The SETTER
    /// stays live so dismissal still clears the selection either way.
    private var detailSheetItem: Binding<SkyObject?> {
        Binding(get: { isRegular ? nil : app.detailDestination },
                set: { app.detailDestination = $0 })
    }

    private var searchPresented: Binding<Bool> {
        Binding(
            get: {
                app.detailDestination == nil
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
    private var clockSchedule: CanvasSchedule {
        CanvasSchedule(isAnimating: app._dateTransition             != nil
                                  || app._originTransition           != nil
                                  || app._rotationTransition         != nil
                                  || app._perspectiveMorphTransition != nil
                                  || app.compassMode)
    }
}

#if DEBUG
#Preview {
    MainView()
        .environment(AppState())
}
#endif

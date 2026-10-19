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

    /// The system Text Size, held to the sky's ceiling — the label
    /// collision pass and the marks it lays out must agree on one size.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var skyTypeSize: DynamicTypeSize { min(dynamicTypeSize, Artist.shared.skyTypeCeiling) }

    /// The floating panel's rest position (regular width only). Owned
    /// here, not by the content, because ONE panel hosts both search and
    /// the detail card and the stage has to survive the swap.
    @State private var panelStage: PanelStage = .bar

    /// The trailing side flips under right-to-left, and the card with it.
    @Environment(\.layoutDirection) private var layoutDirection

    /// iPhone Duo's side rail is up — see `readsSideRail(into:)`.
    @State private var hasRail = false

    /// Search floats in the panel rather than a sheet: regular width, and
    /// iPhone Duo's outer display, where a system sheet runs under the rail
    /// and the panel can stop at it — so the rail runs top to bottom alone.
    /// The place card stays a sheet there: its share / ✕ ride the sheet's
    /// own rail.
    private var searchInPanel: Bool { isRegular || hasRail }

    /// iPhone Duo open, flat or folded: the panel takes the TRAILING side,
    /// beside the rail — the bottom-trailing corner the closed phone's
    /// thumb already knows — instead of the iPad's leading corner.
    private var panelOnTrailing: Bool { isRegular && hasRail }

    /// The place card lives in the floating panel — iPad only. The open
    /// Duo keeps the closed phone's SHEET, placed trailing, where the
    /// system gives it the same side rail (✕ / Find / share), so the card
    /// is one card in every pose.
    private var detailInPanel: Bool { isRegular && !hasRail }

    /// The open Duo's place-card sheet: half the screen, a margin short of
    /// the middle — the hinge, when folded.
    private var trailingSheetWidth: CGFloat {
        max(0, viewSize.width / 2 - FloatingPanel<EmptyView>.margin)
    }

    /// The panel's width when it isn't the iPad's fixed card. Closed: from
    /// the leading margin to a margin short of the rail. Folded like a book:
    /// the iPad card, narrowed if the right page is narrower.
    private var railPanelWidth: CGFloat? {
        let margin = FloatingPanel<EmptyView>.margin
        if !isRegular {
            return viewSize.width - app.skyRailWidth - 2 * margin
        }
        if panelOnTrailing, let page = app.skyFrame {
            return min(FloatingPanel<EmptyView>.width, page.width - 2 * margin)
        }
        return nil
    }

    /// Where the sky composes itself, in screen points — nil for the whole
    /// screen:
    ///   closed (rail, compact) — the screen beside the rail
    ///   folded like a book     — a right page's width, centred on the
    ///                            hinge: the closed phone's zoom, with more
    ///                            sky either side
    ///   flat open, and every other device — the whole screen, so the sky
    ///                            centres on the device
    private var composedSkyFrame: CGRect? {
        let w = viewSize.width, h = viewSize.height
        guard hasRail, w > 0 else { return nil }
        if isRegular, let fold = app.skyFold {
            // The closed phone's zoom — a right page's width — centred on
            // the hinge: no jump in scale, just more sky on either side.
            let page = max(0, w - fold.maxX - app.skyRailWidth)
            return CGRect(x: fold.midX - page / 2, y: 0, width: page, height: h)
        }
        if !isRegular {
            return CGRect(x: 0, y: 0, width: w - app.skyRailWidth, height: h)
        }
        return nil
    }

    /// Publish the sky's frame and re-seed the home zoom to fit it.
    private func publishSkyFrame() {
        let frame = composedSkyFrame
        guard app.skyFrame != frame else { return }
        app.skyFrame = frame
        seedCameraHome(for: viewSize, animated: true)
    }

    /// The fold's band while iPhone Duo stands like a book (a vertical
    /// division), in screen points — nil when flat, closed, or before iOS
    /// 27.1.
    private func bookFold(_ proxy: GeometryProxy) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        let origin = proxy.frame(in: .global).origin
        return proxy.reservedRegions(kind: .division)
            .filter(\.isActive)
            .first { $0.frame.height > $0.frame.width }
            .map { $0.frame.offsetBy(dx: origin.x, dy: origin.y) }
    }

    /// How far the sky slides for the panel. A card lifted to medium or
    /// large covers one side of the disk, so home moves away from it by half
    /// the card's footprint — the disk sits in the middle of the uncovered
    /// sky. The iPad's card is leading, so the sky slides trailing; the
    /// open Duo's is trailing, so it slides leading. At the bar, or with no
    /// card, nothing.
    private var panelHome: CGSize {
        guard cardUp else { return .zero }
        let cardWidth = panelOnTrailing && app.detailDestination != nil
            ? trailingSheetWidth
            : FloatingPanel<EmptyView>.footprint
        let shift   = cardWidth / 2
        let towards = panelOnTrailing ? -shift : shift
        return CGSize(width: layoutDirection == .rightToLeft ? -towards : towards, height: 0)
    }

    /// A card covers part of the sky: the panel lifted past its bar, or —
    /// on the open Duo — the trailing place-card sheet lifted past its
    /// header.
    private var cardUp: Bool {
        guard isRegular else { return false }
        if panelOnTrailing, app.detailDestination != nil {
            return detailDetent != detailHeaderDetent
        }
        return (app.detailDestination != nil || searchPresented.wrappedValue)
            && panelStage != .bar
    }

    /// Where the sky centres, all told: its frame's centre (beside the
    /// Duo's rail, or on the folded book's right page), then the panel's
    /// slide.
    private var skyHome: CGSize {
        let frameShift = app.skyFrame.map { $0.midX - viewSize.width / 2 } ?? 0
        return CGSize(width: frameShift + panelHome.width, height: panelHome.height)
    }

    /// The vertical centre of the front camera the system reserves room
    /// for (iPhone Duo's outer display), in screen points — nil without
    /// one, or before iOS 27.1. The occlusions also include the rail's
    /// status block; the camera is the smallest of them.
    private func frontCameraMidY(_ proxy: GeometryProxy) -> CGFloat? {
        guard #available(iOS 27.1, *) else { return nil }
        let originY = proxy.frame(in: .global).minY
        return proxy.reservedRegions(kind: .occlusion)
            .filter(\.isActive)
            .min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            .map { originY + $0.frame.midY }
    }

    /// The bottom of the lowest region the system reserves at the top of
    /// the rail — its status block, which grows with Live Activities — in
    /// screen points. Nil without one, or before iOS 27.1.
    private func railStatusBottom(_ proxy: GeometryProxy) -> CGFloat? {
        guard #available(iOS 27.1, *) else { return nil }
        let originY = proxy.frame(in: .global).minY
        return proxy.reservedRegions(kind: .occlusion)
            .filter(\.isActive)
            .map { originY + $0.frame.maxY }
            .max()
    }

    /// Publish the rail's width from the safe area it carves out. The rail
    /// stays on the hardware's right in every language, so it's read off
    /// whichever edge is physically right. The camera's home zoom is
    /// re-seeded, since the horizon now fits a narrower sky.
    private func publishRailWidth(_ insets: EdgeInsets) {
        let right = layoutDirection == .rightToLeft ? insets.leading : insets.trailing
        let width = hasRail ? right : 0
        guard app.skyRailWidth != width else { return }
        app.skyRailWidth = width
        publishSkyFrame()
    }


    /// Seed / retune the camera's home + zoom floor from the visible screen
    /// size. The coordinator's built-in 90 approximates an iPhone; on iPad
    /// the horizon launched small until a NorthOUT round-trip happened to
    /// reseed it (the `isNorthOut` onChange). NorthOUT frames itself, so
    /// it's left alone; and only a camera still resting at its old home is
    /// moved — a user zoom survives a resize.
    /// `animated` glides the zoom to its new home instead of snapping —
    /// for a reframe the user watches happen (the Duo opening, folding,
    /// closing), not the silent seed at launch.
    private func seedCameraHome(for size: CGSize, animated: Bool = false) {
        guard !app.isNorthOut else { return }
        let wasHome = abs(sky.scale - sky.defaultScale) < 0.5
        let target  = app.defaultScale(for: size)
        sky.minScale     = northInMinScale(defaultScale: target)
        sky.defaultScale = target
        guard wasHome else { return }
        if animated { sky.glide(to: target) } else { sky.scale = target }
    }

    /// NorthIN zoom floor. Compact: home itself — no pulling back past the
    /// fit-to-height default. Regular width (iPad, iPhone Duo open): opened
    /// DOWN to where a favourite star's name label is still FULLY revealed
    /// — `textIn` plus the 18% fade band (see `POILabelView.tierReveal`) —
    /// so the wide canvas can zoom out further without the favourites
    /// going mute.
    private func northInMinScale(defaultScale target: CGFloat) -> CGFloat {
        guard isRegular else { return target }
        let nameIn = Artist.shared.followedStarTier.textIn * 1.0
        return Swift.min(target, CGFloat(nameIn))
    }

    /// Camera scale/offset captured at the start of a NorthIN↔NorthOUT morph.
    /// The camera glides from these to the committed `sky` target across the
    /// morph (see `perspectiveMorphProgress`), so the reframe animates on the
    /// Canvas in lockstep with the projection instead of snapping.
    @State private var morphScaleFrom:  CGFloat = 0
    @State private var morphOffsetFrom: CGSize  = .zero
    
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
                                 morphOffsetFrom: morphOffsetFrom,
                                 typeSize: skyTypeSize)

            SkyLayerStack(frame: frame)
                // Every mark on the sky follows Text Size up to the ceiling
                // — see `Artist+TypeScale`.
                .dynamicTypeSize(...Artist.shared.skyTypeCeiling)
            
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
                    // The window is steered by the hand, not the fingers.
                    .allowsHitTesting(!app.isLooking)
                    .onAppear {
                        app.syncInterfaceOrientation()
                        sky.center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        sky.onTap  = makeTapHandler()
                        viewSize   = geo.size
                        seedCameraHome(for: geo.size)
                        #if DEBUG
                        // Screenshot seeding: `-skyScale <n>` opens the sky already
                        // zoomed (a device can't be pinched from the command line).
                        let args = ProcessInfo.processInfo.arguments
                        if let i = args.firstIndex(of: "-skyScale"), i + 1 < args.count,
                           let z = Double(args[i + 1]) {
                            // After the camera has seeded its home (and any
                            // NorthIN reframe), or it would put it back — the
                            // simulator's first location fix lands late.
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(4))
                                sky.scale = CGFloat(z)
                            }
                        }
                        // `-panWave` drags the sky round in a slow loop for ten
                        // seconds, as a finger would, and logs the frame rate
                        // it managed (see `MemoryLog`).
                        if args.contains("-panWave") {
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(5))
                                let start = Date.now
                                var last = start, frames = 0, worst = 0.0
                                while Date.now.timeIntervalSince(start) < 10 {
                                    let t = Date.now.timeIntervalSince(start)
                                    sky.drag = CGSize(width: 120 * sin(t * 2), height: 80 * cos(t * 1.3))
                                    try? await Task.sleep(for: .milliseconds(16))
                                    frames += 1
                                    worst = Swift.max(worst, Date.now.timeIntervalSince(last))
                                    last = .now
                                }
                                sky.drag = .zero
                                MemoryLog.note(String(format: "panWave  %.1f fps  worst %.0f ms",
                                                      Double(frames) / 10, worst * 1000))
                            }
                        }
                        // `-pinchWave` pinches in 3× over three seconds through
                        // the real recogniser path (stepped refreshes and all),
                        // then lets go, and logs the frame rate it managed.
                        if args.contains("-pinchWave") {
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(5))
                                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                sky.pinchBegan(centroid: c)
                                let start = Date.now
                                var last = start, frames = 0, worst = 0.0
                                while Date.now.timeIntervalSince(start) < 3 {
                                    let t = Date.now.timeIntervalSince(start) / 3
                                    sky.pinchChanged(scale: CGFloat(exp(t * log(3.0))), centroid: c)
                                    try? await Task.sleep(for: .milliseconds(16))
                                    frames += 1
                                    worst = Swift.max(worst, Date.now.timeIntervalSince(last))
                                    last = .now
                                }
                                sky.pinchEnded()
                                MemoryLog.note(String(format: "pinchWave  %.1f fps  worst %.0f ms",
                                                      Double(frames) / 3, worst * 1000))
                            }
                        }
                        // `-livePinch <n>` freezes a pinch mid-gesture — the
                        // live parent transform held at n× — for measuring
                        // what a pinch costs without a finger on the glass.
                        if let i = args.firstIndex(of: "-livePinch"), i + 1 < args.count,
                           let p = Double(args[i + 1]) {
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(4))
                                sky.pinch = CGFloat(p)
                            }
                        }
                        #endif
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
                        // A rotation reshapes the canvas — the window's
                        // screen-up has to follow the new top edge.
                        app.syncInterfaceOrientation()
                        sky.center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        viewSize   = geo.size
                        seedCameraHome(for: geo.size, animated: true)
                    }
                    .onChange(of: frame.starLabels.deepSky, initial: true) { _, shown in
                        sky.shownDeepSky = shown
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
      // Flat ground, no vignette. This was a RadialGradient running from
      // `canvasBackground` at the centre to `.black.opacity(0.01)` at the
      // rim — and a nearly-TRANSPARENT edge doesn't fade to black, it
      // reveals whatever is behind the app, which is black. Hence the dark
      // corners. The sky's own layers carry the depth now.
      .background(Artist.shared.canvasBackground)
        .preferredColorScheme(.dark)
        .modifier(SkyChrome(viewSize: viewSize, hasRail: hasRail))
        .readsSideRail(into: $hasRail)
        .ignoresSafeArea()
        // The rail's width, measured where the safe area still counts —
        // the sky itself ignores it, so its own geometry reports no insets.
        .background {
            GeometryReader { safe in
                Color.clear
                    .onChange(of: safe.safeAreaInsets, initial: true) { _, insets in
                        publishRailWidth(insets)
                    }
                    .onChange(of: hasRail) { publishRailWidth(safe.safeAreaInsets) }
            }
        }
        // The front camera, measured over the WHOLE screen — it sits
        // outside the safe area, where a safe-area reader can't see it.
        .background {
            GeometryReader { screen in
                Color.clear
                    .onChange(of: frontCameraMidY(screen), initial: true) { _, y in
                        app.skyCameraMidY = y
                    }
                    .onChange(of: railStatusBottom(screen), initial: true) { _, y in
                        app.skyRailStatusBottom = y
                    }
                    .onChange(of: bookFold(screen), initial: true) { _, fold in
                        // Animated, so the chrome that follows the fold (the
                        // Here / Now capsule, the panel) glides to its new
                        // place as the Duo folds or flattens.
                        withAnimation(.smooth(duration: 0.45)) { app.skyFold = fold }
                    }
            }
            .ignoresSafeArea()
        }
        // LOOK mode: holding the phone overhead, belly down, arms it (the
        // ring draws itself); lowering it before the ring closes cancels.
        .onChange(of: MotionService.shared.raisedToSky) { _, raised in
            app.raisedToSkyChanged(raised)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: app.isLooking)
        // Leaving the window: reseed the chart underneath to its HOME
        // framing — default zoom for the current projection, centred —
        // while the window still covers it, so the fold-out eases onto
        // home instead of onto wherever you'd pinched before. Rotation is
        // left as you set it.
        // A place card pulled down past its grid's top folds to its title.
        .onChange(of: app.detailCollapseRequest) {
            withAnimation(.snappy(duration: 0.32)) {
                if detailInPanel { panelStage = .bar } else { detailDetent = detailHeaderDetent }
            }
        }
        .onChange(of: app.isLooking) { _, looking in
            // Opening the window folds a detail card to its header — the
            // sky needs the screen, and the name is on the ring.
            if looking {
                if app.detailDestination != nil { detailDetent = detailHeaderDetent }
                return
            }
            sky.restAtHome()
            sky.scale  = sky.defaultScale
        }
        // The card lifting or dropping moves the sky's centre with it —
        // and so does the Duo's rail arriving or leaving.
        .onChange(of: skyHome) { _, home in sky.moveHome(to: home) }
        // The Duo opening, folding or closing re-frames the sky.
        .onChange(of: app.skyFold) { publishSkyFrame() }
        .onChange(of: isRegular)   { publishSkyFrame() }
        .onChange(of: hasRail)     { publishSkyFrame() }
        .onChange(of: viewSize)    { publishSkyFrame() }

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
        // EVERY sheet below re-injects `app` — see the note on
        // `environment(app)` at the bottom of this file. Without it the
        // Mac (Designed for iPad) build traps at launch.
        // The pills raise these inline editors, same as production MainView.
        .sheet(isPresented: Bindable(app).isShowingLocationPicker) {
            LocationPickerPanel()
                .environment(app)
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
                .environment(app)
                .environment(\.detailCollapsed, detailDetent == detailHeaderDetent)
                .animation(.snappy(duration: 0.28), value: detailDetent)
                .presentationDetents([detailHeaderDetent, .fraction(1.0 / 3.0), .large],
                                     selection: $detailDetent)
                .interactiveDismissDisabled()
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.visible)
                // Open Duo: beside the rail, where the closed phone's card
                // sat — and where the system gives a sheet its own rail.
                .modifier(TrailingSheetPlacement(isActive: panelOnTrailing,
                                                 width:    trailingSheetWidth))
                .tracksBottomSheet()
                .onAppear {
                    detailDetent = .fraction(1.0 / 3.0)
                    #if DEBUG
                    // Screenshot seeding: `-detail large` opens the card
                    // fully (the simulator can't drag a sheet up).
                    if ProcessInfo.processInfo.arguments.contains("-detailLarge") { detailDetent = .large }
                    if ProcessInfo.processInfo.arguments.contains("-detailMini") { detailDetent = detailHeaderDetent }
                    #endif
                }
        }
        // Persistent Apple-Maps search sheet — always up at its bar-only
        // detent whenever nothing else owns the bottom slot. Selecting an
        // object sets `detailDestination`, which flips `searchPresented`
        // false → search yields to the detail sheet. Verbatim production.
        .sheet(isPresented: searchSheetPresented) {
            SearchSheet()
                .environment(app)
                .tracksBottomSheet()
        }
        // Regular width: the same two surfaces, placed rather than
        // presented, sharing ONE card in the bottom-leading corner — the
        // bottom-TRAILING one on the open Duo, beside the rail (which the
        // safe area already keeps it clear of).
        .overlay(alignment: panelOnTrailing ? .bottomTrailing : .bottomLeading) {
            // Same rule the sheet obeys: the panel yields while a scene
            // editor owns the screen. `searchPresented` already excludes
            // both pickers; the panel was ignoring it and left a search bar
            // floating over the date crown.
            if (detailInPanel && app.detailDestination != nil)
                || (searchInPanel && searchPresented.wrappedValue) {
                FloatingPanel(stage: $panelStage,
                              available: viewSize.height,
                              showsDragBand: app.detailDestination != nil,
                              cardWidth: railPanelWidth,
                              edge:      panelOnTrailing ? .trailing : .leading,
                              onExpansion: { e in
                                  let v: CGFloat? = app.detailDestination == nil ? nil : e
                                  if app.detailPanelExpansion != v { app.detailPanelExpansion = v }
                              }) {
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
                // The card keeps its 16pt from the screen's REAL bottom edge,
                // like the Here / Now pill beside it (which is laid out
                // edge-to-edge) — otherwise it floats a home-indicator higher
                // and the two corners no longer share a baseline.
                .ignoresSafeArea(.container, edges: .bottom)
                .transition(.opacity)
                #if DEBUG
                // Screenshot seeding: `-searchOpen` opens the iPad card
                // (a device can't be dragged from the command line).
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("-searchOpen") { panelStage = .large }
                }
                #endif
            }
        }
        // Any selection (canvas tap OR search pick) glides into the comfort
        // zone — one place, so the two paths behave identically.
        .onChange(of: app.detailDestination) { _, obj in
            if let obj { panIntoComfortZone(obj) }
            // The card arriving in the panel should be readable without a
            // drag; leaving it parks the panel back at the search bar.
            if detailInPanel {
                withAnimation(.snappy(duration: 0.32)) {
                    panelStage = obj == nil ? .bar : .large
                }
                if obj == nil { app.detailPanelExpansion = nil }
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
            sky.restAtHome()
            sky.scale        = target
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
        // `animateRotation`, only ever targeting zero). Commit north at once;
        // the VISIBLE spin is the clock-driven `_rotationTransition`, which
        // `SkyFrame` feeds to the camera each tick. NOT `withAnimation`: the
        // canvases can't animate a camera change (they snapped), while the
        // native labels interpolated their `.position` in STRAIGHT LINES —
        // chords across a sky that was turning round its centre.
        .onChange(of: app._rotationTransition?.to) { _, to in
            guard let to, to == .zero else { return }
            sky.rotation = .zero
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
        Binding(get: { !searchInPanel && searchPresented.wrappedValue },
                set: { _ in })
    }

    /// Likewise the detail sheet: where the panel hosts the place card
    /// (iPad), the sheet host is starved of its item. The SETTER stays live
    /// so a real dismissal clears the selection — but NOT the dismissal the
    /// starving itself causes: when the window widens (the Duo opening, an
    /// iPad window stretched) the sheet goes away because the panel took
    /// the card, and writing that nil back dropped the selection.
    private var detailSheetItem: Binding<SkyObject?> {
        Binding(get: { detailInPanel ? nil : app.detailDestination },
                set: { new in
                    if new == nil && detailInPanel { return }
                    app.detailDestination = new
                })
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
                                  || app._lookTransition             != nil
                                  || app.compassMode)
    }
}

// MARK: - TrailingSheetPlacement
// The open iPhone Duo places the place-card sheet on the trailing side,
// beside the rail — the system then gives it a vertical bar, the same side
// rail it has on the closed phone. iOS 27+; elsewhere nothing.
private struct TrailingSheetPlacement: ViewModifier {
    let isActive: Bool
    /// Half the screen — the system's own width ran to two thirds.
    let width:    CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 27.0, *), isActive {
            content
                .presentationPlacement(.trailing)
                .presentationSizing(FixedWidthSizing(width: width))
        } else {
            content
        }
    }
}

/// A sheet of a set width; its height is left to the detents.
private struct FixedWidthSizing: PresentationSizing {
    let width: CGFloat

    func proposedSize(for root: PresentationSizingRoot,
                      context: PresentationSizingContext) -> ProposedViewSize {
        ProposedViewSize(width: width, height: nil)
    }
}

// MARK: - Why every sheet re-injects `app`
// A sheet is NOT part of the view tree it is declared on — SwiftUI hands
// its content to a separate `PresentationHostingController` with its own
// view graph, and seeds that graph's environment from the presenting host
// at the moment of presentation.
//
// The search sheet is up the instant the app draws (it is the resting
// state — see `searchSheetPresented`), so on Mac (Designed for iPad) the
// presentation happens inside UIKit's FIRST commit, before the
// `.environment(state)` written on the `WindowGroup` content has reached
// the hosting view. The presented graph is built without it, the sheet
// root reads `@Environment(AppState.self)`, and SwiftUI traps:
//
//   Fatal error: No Observable object of type AppState found.
//
// iOS gets a launch screen and lays the window out over more than one
// pass, so the environment is in place by the time the sheet presents —
// which is why this only ever showed up on the Mac, and why it showed up
// EVERY launch there (hence the crash → "Reopen" → crash loop).
//
// Writing `.environment(app)` inside the sheet's own content closure puts
// the value in the presented view itself, so it no longer depends on what
// the host managed to inherit. `app` is resolved by then: MainView's body
// has already read it to build the frame.

#if DEBUG
#Preview {
    MainView()
        .environment(AppState())
}
#endif

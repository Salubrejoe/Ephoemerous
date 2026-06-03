import SwiftUI
import UIKit
import CoreLocation
import LoreKit

struct MainView: View {
    @Environment(EAppState.self) var state
    @Environment(\.verticalSizeClass) private var vSizeClass
    /// Inline magnitude slider in the bottom toolbar. Tapping the
    /// magnitude icon toggles it; the slider replaces the Spacer
    /// between the two corner buttons.
    @State private var showMagnitudeSlider = false
    /// Search-sheet presentation. Tapping the search icon presents
    /// `SearchSheet` — Apple-Maps-style sheet with the favourites
    /// horizontal scroll + search results.
    @State private var showSearchSheet = false
    /// Live device orientation. Updated from
    /// `UIDevice.orientationDidChangeNotification`. We need the
    /// actual orientation (not just `verticalSizeClass`) to tell
    /// landscape-left from landscape-right — both are `.compact`
    /// vertically, but the dynamic island sits on opposite sides,
    /// so the sky-fixed rotation has opposite signs.
    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation

    @State private var height : Double = 0.0
    @State private var width : Double = 0.0

    /// Selected detent for the detail place card, so it can fold down to
    /// a header-only stop (Apple-Maps style) while still *opening* at the
    /// third-height. `presentationDetents` takes an unordered Set and
    /// would otherwise present at the smallest member; this binding pins
    /// the initial detent, and the sheet's `.onAppear` resets it to a
    /// third on every fresh presentation.
    @State private var detailDetent: PresentationDetent = .fraction(1.0 / 3.0)

    /// Collapsed detent — just the place card's header (grabber + title
    /// + subtitle + share/close), matching Apple Maps' smallest stop.
    /// ~70pt = the header with its POI icon + body removed (see
    /// `\.detailCollapsed`): top-pad 16 + title 24 + subtitle 18 +
    /// bottom-pad 8. Bump a touch if the subtitle kisses the grabber at
    /// larger Dynamic Type.
    private let detailHeaderDetent: PresentationDetent = .height(70)

    /// Portrait on iPhone is `.regular` vertically; landscape is
    /// `.compact`. In portrait the 64 pt clears the dynamic island
    /// + status bar zone. In landscape the island sits on the side
    /// edge and the screen top is unobstructed, so the toolbar can
    /// sit flush.
    private var topPadding: CGFloat {
        vSizeClass == .compact ? 18 : 64
    }

    /// Sky-fixed canvas rotation. Portrait keeps the projection
    /// upright (celestial-north → screen-top). Landscape rotates so
    /// celestial-north → the dynamic-island edge of the device.
    ///
    /// Apple's `UIDeviceOrientation` naming is counter-intuitive:
    ///   • `.landscapeLeft`  = home button on the RIGHT, DI on screen-LEFT
    ///   • `.landscapeRight` = home button on the LEFT,  DI on screen-RIGHT
    ///
    /// So:
    ///   • portrait          → 0°
    ///   • landscape-left    → +90°  (celestial-up → screen-left)
    ///   • landscape-right   → −90°  (celestial-up → screen-right)
    ///   • face-up/face-down → fall back to vSizeClass-only logic so
    ///                         the rotation doesn't jump to portrait
    ///                         when the user holds the phone flat
    ///                         mid-landscape.
    private var canvasRotation: Angle {
        switch deviceOrientation {
        case .portrait, .portraitUpsideDown:
            return .zero
        case .landscapeLeft:
            return .degrees(+90)
        case .landscapeRight:
            return .degrees(-90)
        default:
            // Unknown / face-up / face-down — use vSizeClass as a
            // proxy. Defaults to landscape-left's rotation while in
            // compact-vertical, which keeps a stable answer instead
            // of snapping to portrait when the device goes flat.
            return vSizeClass == .compact ? .degrees(+90) : .zero
        }
    }
    
    var body: some View {
        ZStack {
            EArtist.shared.canvasBackground
                .ignoresSafeArea()

            CelestialCanva()
            ObjectsTrackingOverlay()

            // Bottom toolbar: date + location pills with inline
            // expandable panels above them. Pinned to the bottom safe
            // area; the canvas stays full-bleed behind it.
            VStack {
                MainToolbar()
                    
                Spacer()
                
                /*
                 HStack(spacing: 12) {
                 Image(symbol: .magnitudeIcon)
                 .bold()
                 .frame(width: 44, height: 44)
                 .contentShape(.circle)
                 .glassEffect(.clear.interactive(), in: .circle)
                 .onTapGesture {
                 withAnimation(.easeInOut(duration: 0.25)) {
                 showMagnitudeSlider.toggle()
                 }
                 }
                 if showMagnitudeSlider {
                 // Stepped magnitude scrubber. `step: 0.2`
                 // makes Apple's stock Slider snap to
                 // discrete increments — no continuous
                 // dragging through fractional values, no
                 // bespoke chrome.
                 Slider(
                 value: Bindable(state).magnitudeFilter,
                 in:    -2.0...8.0,
                 step:  0.2
                 )
                 .tint(.primary)
                 .transition(.opacity.combined(with: .blurReplace))
                 } else {
                 Spacer()
                 }
                 // Search is no longer a button here — it lives in the
                 // persistent SearchSheet pinned to the bottom. (Magnitude
                 // stays for now; its redesign is task #3.)
                 }
                 .frame(height: 44)
                 */
            }
            .padding(.horizontal, 24)
            .padding(.top,        topPadding)
            .padding(.bottom,     32)
        }
        .ignoresSafeArea()
        // Push the sky-fixed rotation onto `state` whenever the size
        // class OR the device orientation flips. The canvas reads
        // `state.canvasRotation` per frame via `EGraphicContext`, so
        // this is what makes celestial-up follow the device's DI edge
        // when the user rotates.
        .onAppear {
            // Start the orientation notification stream and pick up
            // the current orientation as the initial value (the
            // @State default may be `.unknown` until the first
            // notification fires).
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            deviceOrientation = UIDevice.current.orientation
            state.canvasRotation = canvasRotation
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIDevice.orientationDidChangeNotification
        )) { _ in
            deviceOrientation = UIDevice.current.orientation
        }
        .onChange(of: canvasRotation) { _, new in
            state.canvasRotation = new
        }
        // The outer NavigationStack in EphoemerousApp.swift reserves a
        // ~44 pt navigation-bar slot at the top, which pushed the
        // landscape toolbar pills down regardless of any padding inside
        // this view. We don't navigate from MainView itself (sheets
        // host their own NavigationStacks), so the bar is pure ghost
        // chrome — hide it and the toolbar can sit at topPadding = 0.
        .toolbar(.hidden, for: .navigationBar)
        // Detail sheet — single sheet at the root level, item-bound to
        // `state.detailDestination`. Opens at the bottom third; the
        // canvas stays interactive behind it. Two detents, Apple-Maps
        // style: a header-only fold (more canvas, just the place card)
        // and the default third for the detail body. The drag indicator
        // is visible because the user CAN drag between detents (the
        // X-mark in DetailHost still dismisses).
        // Canvas taps go through `state.focus(on:)`, which sets the
        // destination and pans the object to the centre of the upper
        // third.
        .sheet(item: Bindable(state).detailDestination) { obj in
            DetailHost(obj: obj)
                // Fold to header-only when at the smallest detent —
                // DetailHeader drops its icon and each detail view drops
                // its body, so only title + subtitle + buttons remain.
                // Animated so the body slides away rather than snapping.
                .environment(\.detailCollapsed, detailDetent == detailHeaderDetent)
                .animation(.snappy(duration: 0.28), value: detailDetent)
                .presentationDetents(
                    [detailHeaderDetent, .fraction(1.0 / 3.0)],
                    selection: $detailDetent
                )
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.visible)
                // Each fresh place card opens at the third-height, not
                // wherever the previous one was left folded.
                .onAppear { detailDetent = .fraction(1.0 / 3.0) }
        }
        // Myth sheet — sibling root sheet, item-bound to
        // `state.mythDestination`. Adaptive: `.medium` adapts to
        // device class / dynamic type so on small phones it lands
        // around half and on larger devices it lands at the
        // platform-natural medium, and `.large` lets the user drag
        // up to read the full story without the beats being
        // cropped. Drag indicator visible (vs the detail sheet's
        // hidden) because the user CAN drag between detents here.
        // Fired by tapping "Learn the Myth" on a constellation /
        // star detail; `state.openMyth(_:)` dismisses
        // detailDestination first so only one root sheet is on
        // screen at a time.
        .sheet(item: Bindable(state).mythDestination) { myth in
            EMythDetailView(myth: myth)
                .presentationDetents([.medium])
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
        }
        // Persistent search sheet — Apple-Maps-style. It's ALWAYS up
        // (parked at its bar-only detent) whenever nothing else owns the
        // bottom: no object selected and no myth sheet. Selecting an
        // object sets `detailDestination`, which flips this binding false
        // → search dismisses and the detail sheet (above) takes over;
        // dismissing the detail flips it back true → search returns.
        // One source of truth (`detailDestination` / `mythDestination`),
        // so the two sheets are mutually exclusive with no manual toggle.
        .sheet(isPresented: searchPresented) {
            SearchSheet()
        }
        // Location editor — raised by the toolbar's location pill. A
        // proper bottom sheet (swaps search out, same as detail/myth),
        // with its own X to close. `isShowingLocationPicker` is the
        // trigger AND the dismiss flag, so the pill stays lit while it's
        // up. Mutually exclusive with the date editor via the toggle
        // helpers in EAppState+Location.
        .sheet(isPresented: Bindable(state).isShowingLocationPicker) {
            LocationPickerPanel()
                .presentationDetents([.height(300)])
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
        }
        // Date editor — raised by the toolbar's date pill. Wheel picker;
        // a medium sheet is plenty for five wheels + the close row.
        .sheet(isPresented: Bindable(state).isShowingDatePicker) {
            DatePickerPanel()
                .presentationDetents([.height(250)])
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
        }

    }

    /// Search is shown exactly when no other root sheet is — no selected
    /// object, no myth, and neither scene editor (location / date) open.
    /// Read-only derivation with a no-op setter: only an internal swipe
    /// could try to set it false, and `interactiveDismissDisabled(true)`
    /// on the sheet blocks that — a selection or an editor is the only
    /// thing that hides search.
    private var searchPresented: Binding<Bool> {
        Binding(
            get: {
                state.detailDestination == nil
                    && state.mythDestination == nil
                    && !state.isShowingLocationPicker
                    && !state.isShowingDatePicker
            },
            set: { _ in }
        )
    }
}


extension View {
    func sheetFormat() -> some View {
        scrollContentBackground(.hidden)
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled)
    }
}


#Preview("Light") {
    NavigationStack {
        MainView().environment(EAppState())
    }
}

#Preview("Dark") {
    NavigationStack {
        MainView().environment(EAppState())
            .preferredColorScheme(.dark)
    }
}

/*
 .overlay {
 VStack {
 GameBoyControlPad()
 }.padding(.horizontal, 32)
 .frame(maxWidth: 400, maxHeight: 700, alignment: .bottom)
 }


 .toolbar {
 ToolbarItem(placement: .principal) {
 VStack(spacing: 12) {
 CoordinatesTile(origin: state.origin)
 OmniButton()
 }
 }
 }

 .sheet(isPresented: Bindable(state).showStarList) {
 NavigationStack {
 EListView()
 .sheetFormat()
 }
 }
 */

import SwiftUI
import UIKit
import CoreLocation
import LoreKit

struct MainView: View {
    @Environment(EAppState.self) var state
    /// Inline magnitude slider in the bottom toolbar. Tapping the
    /// magnitude icon toggles it; the slider replaces the Spacer
    /// between the two corner buttons.
    @State private var showMagnitudeSlider = false
    /// Search-sheet presentation. Tapping the search icon presents
    /// `SearchSheet` — Apple-Maps-style sheet with the favourites
    /// horizontal scroll + search results.
    @State private var showSearchSheet = false

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

    /// Top inset clearing the dynamic island + status-bar zone. The app
    /// is portrait-only, so this is a constant.
    private let topPadding: CGFloat = 64

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
            }
            .padding(.horizontal, 24)
            .padding(.top,        topPadding)
            .padding(.bottom,     80)
            // Compass rose + heading-up toggle now live in the SearchSheet
            // header (trailing of the search bar), grouped as one cluster —
            // see `SearchSheet`. The old top-trailing overlay is gone.
        }
        .ignoresSafeArea()
        // Engage compass (heading-up) mode when the phone is raised up to
        // the sky — the AR gesture. Engage-only: lifting turns it ON, but
        // it never auto-disengages (the user lowers and taps the toggle to
        // exit). Gated on being at the device location, and we set the flag
        // directly rather than via `toggleCompassMode()` so it doesn't
        // recenter under the user. `raisedToSky` is hysteretic, so this
        // fires once per raise, not repeatedly at the threshold.
        .onChange(of: EMotionService.shared.raisedToSky) { _, raised in
            if raised, state.isAtDeviceLocation, !state.compassMode {
                state.compassMode = true
            }
        }
        // App is portrait-only — no device-orientation rotation. The
        // canvas's `state.canvasRotation` is entirely user-owned (the
        // rotation slider; the two-finger gesture next), so there's no
        // orientation observer here any more.
        //
        // The outer NavigationStack in EphoemerousApp.swift reserves a
        // ~44 pt navigation-bar slot at the top; we don't navigate from
        // MainView itself (sheets host their own NavigationStacks), so
        // the bar is pure ghost chrome — hide it.
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
                .interactiveDismissDisabled()
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
                    // Suppress search during any bottom-slot sheet swap
                    // (detail ⇄ picker, detail → detail / myth) so it
                    // doesn't flash into the teardown gap.
                    && !state._sheetSwapping
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

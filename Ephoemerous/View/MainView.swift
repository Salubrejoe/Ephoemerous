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
                    Image(symbol: .search)
                        .bold()
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                        .glassEffect(.clear.interactive(), in: .circle)
                        .onTapGesture { showSearchSheet = true }
                }
                .frame(height: 44)
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
        // `state.detailDestination`. Bottom third of the screen, canvas
        // stays interactive behind it, no drag indicator (the X-mark in
        // DetailHost is the dismissal affordance). Canvas taps go
        // through `state.focus(on:)`, which sets the destination and
        // pans the object to the centre of the upper third.
        .sheet(item: Bindable(state).detailDestination) { obj in
            DetailHost(obj: obj)
                .presentationDetents([.fraction(1.0 / 3.0)])
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
        }
        // Search sheet — Apple-Maps-style. Tapping the search icon
        // in the bottom toolbar opens this; tapping a favourite card
        // or search result calls `state.focus(on:)` and dismisses,
        // letting the existing detailDestination sheet take over.
        .sheet(isPresented: $showSearchSheet) {
            SearchSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCompactAdaptation(.sheet)
        }

    }
}


extension View {
    func sheetFormat() -> some View {
        scrollContentBackground(.hidden)
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled)
    }
}


#Preview {
    NavigationStack {
        MainView().environment(EAppState())
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

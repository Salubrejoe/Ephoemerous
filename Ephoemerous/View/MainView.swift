import SwiftUI
import CoreLocation
import LoreKit

struct MainView: View {
    @Environment(EAppState.self) var state
    @Environment(\.verticalSizeClass) private var vSizeClass
    @State private var showSortSheet = false

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
                
                HStack {
                    Image(symbol: .magnitudeIcon)
                        .bold()
                        .frame(width:44, height: 44)
                        .contentShape(.circle)
                    .glassEffect(.clear.interactive(), in: .circle)
                    .onTapGesture {
                        showSortSheet = true
                    }
                    Spacer()
                    Image(symbol: .search)
                        .bold()
                        .frame(width:44, height: 44)
                        .contentShape(.circle)
                        .glassEffect(.clear.interactive(), in: .circle)
                        .onTapGesture {
                            //
                        }
                       
//                    SearchBar()
                }
                .frame(height: 44)
            }
            .padding(.horizontal, 24)
            .padding(.top,        topPadding)
            .padding(.bottom,     32)
        }
        .ignoresSafeArea()
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
        .sheet(isPresented: $showSortSheet) {
            FilterView(
                magnitudeCap: Bindable(state).magnitudeFilter,
                magnitudeRange: -2.0...8.0,
                starCount: displayedStars.count
            )
            .presentationDetents([.height(55)])
//            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Bindable(state).showStarList) {
            NavigationStack {
                EListView()
                    .sheetFormat()
            }
        }

    }
    
    private var displayedStars: [EStar] {
        StarDatabase.shared.listableStars
            .filter { $0.name != "Unknown" && $0.magnitude <= state.magnitudeFilter }
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

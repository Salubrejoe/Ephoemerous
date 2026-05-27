import SwiftUI
import CoreLocation
import LoreKit

struct MainView: View {
    @Environment(EAppState.self) var state
    @State private var showSortSheet = false
    
    @State private var height : Double = 0.0
    @State private var width : Double = 0.0
    
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
                        .foregroundStyle(.primary)
                        .frame(width:44, height: 44)
                        .contentShape(.circle)
                    .glassEffect(.clear.interactive(), in: .circle)
                    .onTapGesture {
                        showSortSheet = true
                    }
                    
                    SearchBar()
                }
                .frame(height: 44)
            }
            .padding(.horizontal, 24)
            .padding(.top,        64)
            .padding(.bottom,     32)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSortSheet) {
            FilterView(
                magnitudeCap: Bindable(state).magnitudeFilter,
                magnitudeRange: -2.0...8.0,
                starCount: displayedStars.count
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
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
 .onChange(of: state.magnitudeFilter) { state.persistMagnitudeFilter() }
 
 
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

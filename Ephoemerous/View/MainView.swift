import SwiftUI
import CoreLocation
import LoreKit

struct MainView: View {
    @Environment(EAppState.self) var state
    
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
                Spacer()
                MainToolbar()
                    .padding(.horizontal, 24)
                    .padding(.bottom,     32)
            }
        }
        .ignoresSafeArea()
//        .ignoresSafeArea(.container, edges: .top)

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
 .onChange(of: state.layerVisibilitySignature) { state.persistLayerVisibility() }
 .onChange(of: state.magnitudeFilter)          { state.persistLayerVisibility() }
 
 
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

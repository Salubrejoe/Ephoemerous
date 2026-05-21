import SwiftUI
import CoreLocation

struct MainView: View {
    @Environment(EAppState.self) var state
    
    @State private var height : Double = 0.0
    @State private var width : Double = 0.0
    
    var body: some View {
        ZStack {
            Color.secondarySystemBackground
                .ignoresSafeArea()
                
            // Travel backdrop moved into CelestialCanva's travel group so it
            // cross-fades with the sky on the same blend.
            CelestialCanva()
            ObjectsTrackingOverlay()
            OmniButton()
        }
        .ignoresSafeArea()
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
                CoordinatesTile(origin: state.origin)
            }
        }
        
        .sheet(isPresented: Bindable(state).showStarList) {
            NavigationStack {
                EListView()
                    .sheetFormat()
            }
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

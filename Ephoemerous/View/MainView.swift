import SwiftUI
import CoreLocation

struct MainView: View {
    @Environment(EAppState.self) var state
    
    var body: some View {
        ZStack {
            
            if state.appMode == .clock {
                
//                ESkyBackground()
                LinearGradient(colors: [
                    Color.darkIndigo,
                    Color.darkBerry,
                ], startPoint: .top, endPoint: .bottom)
                    .mask(
                        Circle()
                            .frame(
                                width:  2 * state.scale * ENSWatchCrownLayer.clipRadius,
                                height: 2 * state.scale * ENSWatchCrownLayer.clipRadius
                            )
                            .offset(x: state.offset.y, y: state.offset.x)
                    )
            } else {
//                ESkyBackground()
                LinearGradient(colors: [
                    Color.darkIndigo,
                    Color.darkBerry,
                ], startPoint: .top, endPoint: .bottom)
            }
            
            CelestialCanva()
            
            ObjectsTrackingOverlay()
        }
        .ignoresSafeArea()
        .overlay {
            HStack {
                CoordinatesTile(origin: state.origin)
                    .frame(width: 100)
                
                CircledResetButton()
                    .frame(width: 150)
                
                
                ProjectionModePicker()
                    .frame(width: 100)
            }
            .frame(maxHeight: 700, alignment: .top)
            
        }
        .onChange(of: state.layerVisibilitySignature) { state.persistLayerVisibility() }
        .onChange(of: state.magnitudeFilter)          { state.persistLayerVisibility() }
        
        
        .toolbar {
            
            ToolbarItem(placement: .bottomBar) { DateButton() }
            
            ToolbarItem(placement: .status) { SearchBar() }
            
            ToolbarItem(placement: .bottomBar) { ZenithButton() }
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
    MainView().environment(EAppState())
}

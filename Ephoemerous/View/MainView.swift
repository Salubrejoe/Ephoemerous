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
        .onChange(of: layerVisibilityHash) { ECloudSync.shared.saveLayerVisibility(state) }
        .onChange(of: state.magnitudeFilter) { ECloudSync.shared.saveLayerVisibility(state) }
        
        
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
    
    // Bitmask to detect any layer toggle change in one .onChange
    private var layerVisibilityHash: Int {
        (state.showEquatorTropics  ? 1   : 0) |
        (state.showEcliptic        ? 2   : 0) |
        (state.showNSMeridians     ? 4   : 0) |
        (state.showULMeridians     ? 8   : 0) |
        (state.showHorizon         ? 16  : 0) |
        (state.showStars           ? 32  : 0) |
        (state.showPlanets         ? 64  : 0) |
        (state.showSelectedStars   ? 128 : 0)
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

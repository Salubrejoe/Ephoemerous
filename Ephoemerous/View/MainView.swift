import SwiftUI
import CoreLocation

struct MainView: View {
    @Environment(EAppState.self) var state
    
    var body: some View {
        ZStack {
            
            if state.appMode == .clock {
                
//                ESkyBackground()
                Circle()
                    .fill(LinearGradient(colors: [
                        .darkIndigo,
                        .darkIndigo.opacity(0.5)
                    ], startPoint: .top, endPoint: .bottom))
                    .frame(
                        width:  2 * state.renderedScale * ENSWatchCrownLayer.clipRadius,
                        height: 2 * state.renderedScale * ENSWatchCrownLayer.clipRadius
                    )
                    .offset(x: state.renderedOffset.y, y: state.renderedOffset.x)
                    
            } else {
//                ESkyBackground()
                Rectangle()
                    .fill(LinearGradient(colors: [
                        .darkIndigo,
                        .darkIndigo.opacity(0.5)
                    ], startPoint: .top, endPoint: .bottom))
                
            }
            
            CelestialCanva()
            
            ObjectsTrackingOverlay()

        }
        .navigationTitle(Strings.App.name)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea()
        .overlay {
            HStack {
//                CoordinatesTile(origin: state.origin)
//                    .frame(width: 100)
//                
//                CircledResetButton()
//                    .frame(width: 150)
//                
//                
//                ProjectionModePicker()
//                    .frame(width: 100)
                GameBoyControlPad()
            }
            .frame(maxWidth: 300, maxHeight: 700, alignment: .bottom)
            
        }
        .onChange(of: state.layerVisibilitySignature) { state.persistLayerVisibility() }
        .onChange(of: state.magnitudeFilter)          { state.persistLayerVisibility() }
        
        
//        .toolbar {
//            
//            ToolbarItem(placement: .bottomBar) { DateButton() }
//            
//            ToolbarItem(placement: .status) { SearchBar() }
//            
//            ToolbarItem(placement: .bottomBar) { ZenithButton() }
//        }
        
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

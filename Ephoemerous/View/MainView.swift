import SwiftUI
import CoreLocation

struct MainView: View {
    @Environment(EAppState.self) var state
    
    @State private var height : Double = 0.0
    @State private var width : Double = 0.0
    
    var body: some View {
        ZStack {
            
            // Clock-mode sky disc is now a back-most layer in the inner
            // canvas (ESkyBackgroundLayer) — anchored exactly like the
            // stars/crown. Travel keeps a plain full-screen fill.
            if state.appMode == .travel {
                Rectangle()
                    .fill(LinearGradient(colors: [
                        .darkIndigo,
                        .darkIndigo.opacity(0.5)
                    ], startPoint: .top, endPoint: .bottom))
            }
            
            CelestialCanva()
            
            ObjectsTrackingOverlay()

        }
        .onGeometryChange(for: CGSize.self, of: { geo in
            geo.size
        }, action: { newSize in
            height = newSize.height
            width = newSize.width
        })
//        .navigationTitle(Strings.App.name)
//        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea()
//        .overlay {
//            HStack {
//                // Needs to pull from ELocationService the name of the locality approx.
//                HStack(spacing: 2) {
//                    //if location is not user location
//                    Image(systemName: "reset.circle.fill")
//                        .glassEffect(.clear.tint(.baseOrange).interactive(), in: .circle)
//                        .padding(.leading, 2)
//                    //
//                    
//                    Image(symbol: .location)
//                    Text("Brighton")
//                }
//                .font(.caption)
//                .frame(width: 100)
//                
//                Spacer()
//                // if state.scale and scale.offset are not the default
//                CircledResetButton()
//                //
//                Spacer()
//                // Needs to pull from appState the observation date
//                HStack(spacing: 2) {
//                    Image(systemName: "18.calendar")
//                    Text("May 26")
//                    //if observation date is not current date
//                    Image(systemName: "reset.circle.fill")
//                        .glassEffect(.clear.tint(.baseCoral).interactive(), in: .circle)
//                        .padding(.leading, 2)
//                    //
//                }
//                .font(.caption)
//                .frame(width: 100)
//            }
//            .frame(maxWidth: 400, maxHeight: 700, alignment: .top)
//            
//        }
//        .overlay {
//            VStack {
//                if state.scale != state.defaultScale || state.offset !=  state.defaultOffset {
//                    CircledResetButton()
//                }
//                Spacer()
//                GameBoyControlPad()
//            }.padding(.horizontal, 32)
//                .frame(maxWidth: width, maxHeight: height, alignment: .bottom)
//        }
        .onChange(of: state.layerVisibilitySignature) { state.persistLayerVisibility() }
        .onChange(of: state.magnitudeFilter)          { state.persistLayerVisibility() }
        
        
        .toolbar {
//            
//            ToolbarItem(placement: .bottomBar) { DateButton() }
//            
//            ToolbarItem(placement: .status) {
////                SearchBar()
//                GameBoyControlPad()
//            }
//            
//            ToolbarItem(placement: .bottomBar) { ZenithButton() }
            ToolbarItem(placement: .principal) { CoordinatesTile(origin: state.origin) }
//
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

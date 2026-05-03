import SwiftUI
import CoreLocation

struct MainView: View {
    @Environment(EAppState.self) var state
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.1), .blue.opacity(0.2)], startPoint: .bottom, endPoint: .top)
            
            CelestialCanva()
            
            ObjectsTrackingOverlay()
        }
        .overlay {
            HStack {
                CoordinatesTile(origin: state.origin)
                    .frame(width: 100)
                
                CircledResetButton()
                    .frame(maxWidth: .infinity)
                
                
                ProjectionModePicker()
                    .frame(width: 100)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 72)
            .padding(.horizontal, 16)
            
        }
        .ignoresSafeArea()
        .onAppear { state.applyTimeOfDayPreset() }
        .onChange(of: state.observationDate) { state.applyTimeOfDayPreset() }
        .onChange(of: layerVisibilityHash) { ECloudSync.shared.saveLayerVisibility(state) }
        
        .zenithButton(placement: .bottomBar)
        .toolbar {
            
            ToolbarItem(placement: .bottomBar) {
                DateButton()
            }
            
            ToolbarItem(placement: .status) {
                if !state.isShowingDatePicker || state.showStarList {
                    SearchBar(showStarList: Bindable(state).showStarList)
                }
            }
        }
        
        .sheet(isPresented: Bindable(state).showStarList) {
            NavigationStack {
                EListView()
                    .scrollContentBackground(.hidden)
                    .presentationDetents([.medium, .large])
                    .presentationBackgroundInteraction(.enabled)
            }
        }
        
        .sheet(isPresented: Bindable(state).showMagnFilter) {
            FilterView(
                magnitudeCap: Bindable(state).magnitudeFilter,
                magnitudeRange: -2.0...8.0,
                starCount: StarDatabase.shared.workableStars.filter { $0.magnitude <= state.magnitudeFilter && $0.name != "Unknown" }.count
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        
        .sheet(isPresented: Bindable(state).showSunInfo) {
            NavigationStack {
                ENSSunDetailView()
                    .scrollContentBackground(.hidden)
                    .presentationDetents([.medium, .large])
                    .presentationBackgroundInteraction(.enabled)
            }
        }
        
        .sheet(isPresented: Bindable(state).showMoonInfo) {
            NavigationStack {
                ENSMoonDetailView()
                    .scrollContentBackground(.hidden)
                    .presentationDetents([.medium, .large])
                    .presentationBackgroundInteraction(.enabled)
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

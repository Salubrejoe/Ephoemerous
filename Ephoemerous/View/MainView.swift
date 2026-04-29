import SwiftUI

struct MainView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(EAppState.self) var state
    @State private var showStarList    = false
    @State private var showMagnFilter = false
    
    var body: some View {
        ZStack {
            if colorScheme == .light {
                Color.secondarySystemFill
//                Color.systemGray3
            } else {
                Color.secondarySystemFill
            }
            
            CelestialCanva()
            
            SunMoonTrackingOverlay()
        }
        .ignoresSafeArea()
        .onAppear          { state.applyTimeOfDayPreset() }
        .onChange(of: state.observationDate) { state.applyTimeOfDayPreset() }
        
        // ANIMATION
        /*
         .animation(.bouncy, value: state.observationDate)
         .animation(.bouncy, value: state.offset)
         .animation(.bouncy, value: state.scale)
         .animation(.bouncy, value: state.origin)
         .animation(.bouncy, value: state.plane)
         */
        
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    state.scale = AstroConstants.defaultScale
                    state.offset = .init(x: AstroConstants.defaultOffsetX, y: AstroConstants.defaultOffsetY)
                } label: {
                    Image(symbol: .circle)
                }
                .disabled(!(state.scale != 50.0 || state.offset != .init(x: AstroConstants.defaultOffsetX, y: AstroConstants.defaultOffsetY)))
            }
            
            ToolbarItem(placement: .bottomBar) {
                DateButton()
            }
            
            ToolbarItem(placement: .bottomBar) {
                if !state.isShowingDatePicker || state.showStarList {
                    ZenithButton(state: state)
                }
            }
            
            ToolbarItem(placement: .status) {
                if !state.isShowingDatePicker || state.showStarList {
                    SearchBar(showStarList: Bindable(state).showStarList)
                }
            }
        }
        
        // LIST
        .sheet(isPresented: Bindable(state).showStarList) {
            NavigationStack {
                EListView()
                    .scrollContentBackground(.hidden)
                    .presentationDetents([.medium, .large])
                    .presentationBackgroundInteraction(.enabled)
            }
        }
        .sheet(isPresented: $showMagnFilter) {
            EMagnitudeSlider(
                magnitudeCap: Bindable(state).magnitudeFilter,
                magnitudeRange: -2.0...8.0,
                starCount: StarDatabase.shared.workableStars.filter { $0.magnitude <= state.magnitudeFilter && $0.name != "Unknown" }.count
            )
            .presentationDetents([.height(78)])
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
}

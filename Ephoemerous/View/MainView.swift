import SwiftUI

struct MainView: View {
    
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
                    state.scale = 50.0
                    state.offset = .init(x: -80, y: 0)
                } label: {
                    Image(symbol: .circle)
                }
                .disabled(!(state.scale != 50.0 || state.offset != .init(x: -80, y: 0)))
            }
            
            ToolbarItem(placement: .bottomBar) {
                DateButton()
            }
            ToolbarItem(placement: .cancellationAction) {
                Button { showMagnFilter = true } label: { Image(symbol: .magnitudeIcon) }
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
        .bottomSheet(
            .listTitle,
            isPresented: Bindable(state).showStarList,
            content: {
                EListView()
                    .scrollContentBackground(.hidden)
            }
        )
        
        .sheet(isPresented: Bindable(state).showStarList) {
            EListView()
                .scrollContentBackground(.hidden)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled)
        }
//        .sheet(isPresented: $showMagnFilter) {
//            ESortFilterSheet(
//                magnitudeCap: Bindable(state).magnitudeFilter,
//                magnitudeRange: -2.0...8.0,
//                starCount: StarDatabase.shared.workableStars.filter { $0.magnitude <= state.magnitudeFilter && $0.name != "Unknown" }.count
//            )
//            .presentationDetents([.height(78)])
//            .presentationDragIndicator(.visible)
//        }
        
        .sheet(isPresented: Bindable(state).showSunInfo) {
            ENSSunDetailView()
                .scrollContentBackground(.hidden)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled)
        }
        
        .sheet(isPresented: Bindable(state).showMoonInfo) {
            ENSMoonDetailView()
                .scrollContentBackground(.hidden)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled)
        }
    }
}

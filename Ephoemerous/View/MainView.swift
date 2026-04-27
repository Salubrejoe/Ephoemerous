import SwiftUI

struct MainView: View {
    
    @Environment(EAppState.self) var state
    @State private var showStarList = false
    
    var body: some View {
        ZStack {
            Color.secondarySystemFill
            
            CelestialCanva()
            
            SunMoonTrackingOverlay()
        }
        .ignoresSafeArea()
        
        // ANIMATION
        /*
         .animation(.bouncy, value: state.observationDate)
         .animation(.bouncy, value: state.offset)
         .animation(.bouncy, value: state.scale)
         .animation(.bouncy, value: state.origin)
         .animation(.bouncy, value: state.plane)
         */
        
        .toolbar {
            ToolbarItem(placement: .bottomBar, ) {
                HStack {
                    DateButton()
                    ZenithButton(state: state)
                }
            }
            
            ToolbarItem(placement: .status) {
                if !state.isShowingDatePicker {
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
                    .navigationTitle(Strings.App.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .scrollContentBackground(.hidden)
            }
        )
        
        .bottomSheet(
            .sun,
            isPresented: Bindable(state).showSunInfo,
            content: { ENSSunDetailView() }
        )
        .bottomSheet(
            .sun,
            isPresented: Bindable(state).showMoonInfo,
            content: { ENSSunDetailView() }
        )
    }
}

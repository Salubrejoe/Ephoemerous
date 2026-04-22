import SwiftUI

struct MainView: View {

    @Environment(EAppState.self) var state
    @State private var showStarList = false

    var body: some View {
        NavigationStack {
            ZStack {
                ESkyCanvaView()
                WatchCrown()
                    .offset(y: -91)
            }

            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showStarList = true
                    } label: {
                        Label("Stars", systemImage: "magnifyingglass")
                    }
                }

                ToolbarItem(placement: .status) {
                    Button {
                        state.isEditingDate.toggle()
                    } label: {
                        HStack {
                            Text(state.observationDate, style: .time)
                                .bold()
                                .padding()
                        }
                    }
//                    .frame(height: 55)
                }
            }

            .navigationTitle("Ephemerous")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                EDatePicker()
            }
            .sheet(isPresented: $showStarList) {
                NavigationStack {
                    EStarListView()
                }
                .environment(state)
//                .preferredColorScheme(.dark)
            }
        }
    }
}

#Preview {
    MainView()
        .environment(EAppState())
}

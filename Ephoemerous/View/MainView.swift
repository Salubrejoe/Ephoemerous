import SwiftUI

struct MainView: View {
    
    @Environment(EAppState.self) var state
    
    var body: some View {
        NavigationStack {
            ECanvasView()
                .toolbar {
                    
                    ToolbarItem(placement: .bottomBar) {
                        EProjectionModePicker(state: state)
                            .frame(width: 55, height: 55)
                    }
                    
                    ToolbarItem(placement: .status) {
                        Button {
                            state.isEditingDate.toggle()
                        } label: {
                            HStack {
                                Text(state.observationDate.formatted(.dateTime))
                                    .bold()
                                    .padding()
                            }
                        }
                        .tint(.pink)
                        .frame(height: 55)
                    }
                    
                    ToolbarItem(placement: .bottomBar) {
                        EZenithButton(state: state)
                            .frame(width: 55, height: 55)
                    }
                }
                .navigationTitle("Ephemerous")
                .navigationBarTitleDisplayMode(.inline)
                .overlay {
                    EDatePicker()
                }
        }
    }
}

#Preview {
    MainView()
}


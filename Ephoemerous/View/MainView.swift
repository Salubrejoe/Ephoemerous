import SwiftUI

struct MainView: View {

    @Environment(EAppState.self) var state
    @State private var showStarList = false

    var body: some View {
        NavigationStack {
            let bindableState = Bindable(state)
            ZStack {
                ESkyCanvaView()
                WatchCrown()
                    .offset(y: state.offset.x)
            }
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .status) {
                    if !state.isEditingDate {
                        
                        Button {
                            showStarList = true
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Search the sky...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    if !Calendar.current.isDateInToday(state.observationDate) {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                state.observationDate = .now
                            }
                        } label: {
                            Label("Now", systemImage: "clock.arrow.circlepath")
                                .foregroundStyle(.yellow)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    if state.isEditingDate {
                        
                        HStack {
                            DatePicker("", selection: bindableState.observationDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                    } else {
                        
                        Button {
                            withAnimation {
                                state.isEditingDate.toggle()
                            }
                        } label: {
                            
                            Image(systemName: "calendar")
                        }
                    }
//                    .frame(height: 55)
                }
                
                ToolbarItem(placement: .bottomBar) {
                    if !state.isEditingDate {
                        EZenithButton(state: state)
                    } else {
                        Button {
                            withAnimation {
                                state.isEditingDate.toggle()
                            }
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    if !Calendar.current.isDateInToday(state.observationDate) {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                state.observationDate = .now
                            }
                        } label: {
                            Label("Now", systemImage: "clock.arrow.circlepath")
                                .foregroundStyle(.yellow)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }

            
            .sheet(isPresented: Bindable(state).showSunInfo) {
                NavigationStack {
                    ENSSunDetailView()
                }
            }
            .sheet(isPresented: Bindable(state).showMoonInfo) {
                NavigationStack {
                    ENSMoonDetailView()
                }
            }
        .navigationTitle("Ephemerous")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showStarList) {
                NavigationStack {
                    EStarListView()
                }
                .presentationDetents([.fraction(0.6)])
                .presentationDragIndicator(.visible)
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

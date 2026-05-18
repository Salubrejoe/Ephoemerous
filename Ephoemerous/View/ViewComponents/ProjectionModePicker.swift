import SwiftUI

struct ProjectionModePicker: View {
    @Environment(EAppState.self) var state

    var body: some View {
        Picker("", selection: Bindable(state).projectionMode) {
            ForEach(visibleModes, id: \.self) { mode in
                Image(systemName: mode.symbol)
                    .tag(mode)
            }
        }
        .environment(\.colorScheme, .dark)
        .pickerStyle(.segmented)
        .animation(.easeInOut(duration: 0.3), value: state.appMode)
        .background(highlights())
    }

    private var visibleModes: [ProjectionMode] {
        state.appMode == .travel ? ProjectionMode.allCases : [.drag, .coupled]
    }
    
    private var color1 : Color {
        state.projectionMode == .coupled ? .baseOrange : .clear
    }
    
    private var color2 : Color {
        state.projectionMode == .origin ? .baseCoral : .clear
    }
    
    @ViewBuilder
    private func highlights() -> some View {
        HStack(spacing:2) {
            Capsule().fill(.clear)
            Capsule()
                .stroke(color1)
            if state.appMode == .travel {
                Capsule()
                    .stroke(color2)
            }
        }
        .padding([.top, .horizontal], 1)
    }
}

#Preview {
    ProjectionModePicker().environment(EAppState())
}

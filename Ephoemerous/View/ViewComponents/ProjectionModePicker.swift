import SwiftUI

struct ProjectionModePicker: View {
    @Environment(EAppState.self) var state

    var body: some View {
        Picker("", selection: Bindable(state).projectionMode) {
            ForEach(visibleModes, id: \.self) { mode in
                Image(systemName: mode.symbol)
                    .foregroundStyle(mode.color)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .animation(.easeInOut(duration: 0.3), value: state.appMode)
        .background(
            HStack(spacing:2) {
                Capsule().fill(.clear)
                Capsule().fill(color1)
                    .shadow(color: color1, radius: 2)
                if state.appMode == .travel {
                    Capsule().fill(color2)
                        .shadow(color: color2, radius: 2)
                }
            }
                .padding([.top, .horizontal], 1)
        )
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
}

#Preview {
    ProjectionModePicker().environment(EAppState())
}

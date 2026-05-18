import SwiftUI

struct ProjectionModePicker: View {
    @Environment(EAppState.self) var state

    var body: some View {
        Picker("", selection: Bindable(state).projectionMode) {
            ForEach(state.selectableProjectionModes, id: \.self) { mode in
                Image(systemName: mode.symbol)
                    .tag(mode)
            }
        }
        .environment(\.colorScheme, .dark)
        .pickerStyle(.segmented)
        .animation(.easeInOut(duration: 0.3), value: state.appMode)
        .background(highlights())
    }

    private var coupledHighlight: Color {
        state.projectionMode == .coupled ? .baseOrange : .clear
    }

    private var originHighlight: Color {
        state.projectionMode == .origin ? .baseCoral : .clear
    }
    
    @ViewBuilder
    private func highlights() -> some View {
        HStack(spacing:2) {
            Capsule().fill(.clear)
            Capsule()
                .stroke(coupledHighlight)
            if state.appMode == .travel {
                Capsule()
                    .stroke(originHighlight)
            }
        }
        .padding([.top, .horizontal], 1)
    }
}

#Preview {
    ProjectionModePicker().environment(EAppState())
}

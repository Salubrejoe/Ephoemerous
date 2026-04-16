import SwiftUI


struct EProjectionModePicker: View {

    @Bindable var state: EAppState

    var body: some View {
        Picker("Projection", selection: $state.projectionMode) {
            ForEach(ProjectionMode.allCases, id: \.self) {
                Image(systemName: $0.symbol)
                    .foregroundStyle(.yellow)
                    .tag($0)
            }
        }
        .pickerStyle(.automatic)
        .labelsHidden()
    }
}

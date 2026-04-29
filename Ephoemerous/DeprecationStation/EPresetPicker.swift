import SwiftUI

// MARK: - EPresetPicker
struct EPresetPicker: View {

    @Environment(EAppState.self) var state

    var body: some View {
        HStack(spacing: 4) {
            ForEach(EViewPreset.all) { preset in
                PresetButton(preset: preset, isActive: state.activePreset == preset) {
                    preset.id == "trackSun" ? state.applySunTracking() : state.apply(preset)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - PresetButton
private struct PresetButton: View {

    let preset: EViewPreset
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: preset.symbol)
//                .font(.system(size: 15, weight: isActive ? .semibold : .regular))
//                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 38, height: 30)
//                .background(
//                    isActive
//                        ? AnyShapeStyle(.regularMaterial)
//                        : AnyShapeStyle(Color.clear),
//                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
//                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.name)
    }
}

#Preview {
    EPresetPicker()
        .environment(EAppState())
        .padding()
}

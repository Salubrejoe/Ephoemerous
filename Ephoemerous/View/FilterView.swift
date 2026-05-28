import SwiftUI

// MARK: - FilterView
// The only filter knob the app exposes is the star magnitude cap —
// per-layer toggles were dropped when every layer became permanently
// visible. The slider clamps `state.magnitudeFilter`; MainView's
// `.onChange` writes the value through to iCloud.
struct FilterView: View {

    @Binding var magnitudeCap: Double
    let magnitudeRange: ClosedRange<Double>
    let starCount: Int
    @Environment(EAppState.self) var state

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Text(Strings.Sort.brighterThan)
//                    .font(.subheadline.weight(.medium))
//                Spacer()
//                Text(String(format: Strings.Format.magnFormat, magnitudeCap))
//                    .monospacedDigit()
//                    .foregroundStyle(.secondary)
//                Spacer()
//                Text("\(starCount) stars")
//                    .font(.caption)
//                    .foregroundStyle(.tertiary)
//            }
            Slider(value: $magnitudeCap, in: magnitudeRange, step: 0.1)
                .tint(.primary)
        }
        .padding()
    }
}

#Preview {
    FilterView(magnitudeCap: .constant(5.5), magnitudeRange: -2...8, starCount: 1234)
        .environment(EAppState())
}

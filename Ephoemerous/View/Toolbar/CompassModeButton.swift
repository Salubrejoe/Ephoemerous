import SwiftUI

// MARK: - CompassModeButton
// Heading-up toggle, stacked beneath the compass rose. Tapping it makes
// the map act like a compass: the canvas spins so the phone's heading is
// always at the top while the aim cone stays fixed pointing up (the phone
// becomes the dial). Tap again to drop out, freezing the map where the
// heading left it.
//
// Only shown when device motion is available — in the Simulator (no gyro)
// there's no heading to follow, so the toggle hides entirely rather than
// offering a dead control. The glass circle + size mirror `CompassButton`
// so the two read as one stacked rotation cluster.
struct CompassModeButton: View {

    @Environment(EAppState.self) private var state

    private let haptic   = UIImpactFeedbackGenerator(style: .medium)
    private let faceSize: CGFloat = 46

    var body: some View {
        // No gyro → nothing to follow; don't offer the control at all.
        if EMotionService.shared.isAvailable {
            let on = state.compassMode

            Button {
                haptic.impactOccurred()
                state.toggleCompassMode()
            } label: {
                Image(systemName: on ? "location.north.line.fill" : "location.north.line")
                    .font(.system(size: 17, weight: .semibold))
                    // Lit orange (matching the rose's north tip) while
                    // active; muted when off.
//                    .frame(width: faceSize, height: faceSize)
                    .padding(.horizontal, 14)
                    .padding(.vertical,   10)
                    .clipShape(.circle)
                    .foregroundStyle(.orange)
                    .background(
                        Circle().fill(.ultraThinMaterial)
                    )
//                    .glassEffect(.regular.interactive(), in: .circle)
            }
//            .buttonStyle(CompassModePressStyle())
            .buttonStyle(.glass)
            .animation(.snappy(duration: 0.25), value: on)
        }
    }
}

// MARK: - CompassModePressStyle
// Springy shrink on press — same physical feel as the compass rose.
private struct CompassModePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.84 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5),
                       value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        CompassModeButton()
            .environment(EAppState())
    }
}

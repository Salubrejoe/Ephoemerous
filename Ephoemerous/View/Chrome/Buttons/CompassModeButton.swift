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

    @Environment(AppState.self) private var state

    /// `bare` = no glass of its own — for riding inside the shared camera
    /// capsule; the engaged state is spoken by the glyph tint (Maps' blue
    /// arrow), not a segment fill.
    var bare: Bool = false

    private let haptic   = UIImpactFeedbackGenerator(style: .medium)
    private let faceSize: CGFloat = 44

    var body: some View {
        // No gyro → nothing to follow; don't offer the control at all.
        if MotionService.shared.isAvailable {
            let on = state.compassMode

            let button = Button {
                haptic.impactOccurred()
                state.toggleCompassMode()
            } label: {
                // Font-sized (not .resizable-stretched) so the stroke weight
                // stays on the SF Symbols optical grid and matches the flip
                // glyph. ▼ TWEAK size/weight here (pairs with the flip) ▼
                Image(systemName: on ? "location.north.line.fill" : "location.north.line")
                    .font(.system(size: 21, weight: .medium))
                    .frame(width: faceSize, height: faceSize)
                    // The full face is the tap target — in `bare` mode there's
                    // no interactive glass of its own, and without this the
                    // hit area collapses to the glyph's hairline strokes.
                    .contentShape(.rect)
                    .foregroundStyle(bare ? (on ? Color.accentColor : Color.primary)
                                          : (on ? Color.white       : Color.primary))
            }
            .buttonStyle(.plain)
            .animation(.snappy(duration: 0.25), value: on)

            if bare {
                button
            } else {
                // Standalone — carries its own glass. Accent = "live/engaged";
                // it EARNS its fill while compassing, quiet glass at rest.
                button.glassEffect(.regular.tint(
                    on ? Color.accentColor : .clear
                ).interactive(), in: .circle)
            }
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

#if DEBUG
#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        CompassModeButton()
            .environment(AppState())
    }
}
#endif

import SwiftUI

// MARK: - ProjectionFlipButton
// Toggles NorthOUT — the celestial-pole-centred perspective: the sky becomes
// a fixed map centred on the South celestial pole with the visible sky
// OUTSIDE the horizon, and the horizon becomes the moving element. Hidden in
// compass mode (the two perspectives are mutually exclusive). Glass circle
// mirrors `CompassModeButton` so the top control cluster reads as one family.
struct ProjectionFlipButton: View {

    @Environment(AppState.self) private var state

    /// `bare` = no glass of its own — for riding inside the shared camera
    /// capsule, where the container carries the glass and the ENGAGED state
    /// is spoken by the glyph tint (Maps' blue arrow), not a segment fill.
    var bare: Bool = false

    private let haptic   = UIImpactFeedbackGenerator(style: .medium)
    private let faceSize: CGFloat = 44

    var body: some View {
        let on = state.isNorthOut

        let button = Button {
            haptic.impactOccurred()
            state.toggleSkyPerspective()
        } label: {
            // A sphere with orbit arrows — "turn the celestial sphere
            // around" — honest about what the toggle does, unlike the old
            // abstract dot-in-ring. Font-sized (not .resizable-stretched)
            // so its stroke weight matches the compass glyph below it.
            // ▼ TWEAK size/weight here (pairs with compass-mode) ▼
            Image(systemName: "rotate.3d")
                .font(.system(size: 21, weight: .medium))
                .frame(width: faceSize, height: faceSize)
                // Full-face tap target — see CompassModeButton.
                .contentShape(.rect)
                .foregroundStyle(bare ? (on ? Color.accentColor : Color.primary)
                                      : (on ? Color.white       : Color.primary))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.25), value: on)

        if bare {
            button
        } else {
            // Standalone — carries its own glass. Accent = "live/engaged",
            // nothing is accent-filled at rest.
            button.glassEffect(.regular.tint(on ? Color.accentColor : .clear)
                .interactive(), in: .circle)
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        ProjectionFlipButton()
            .environment(AppState())
    }
}
#endif

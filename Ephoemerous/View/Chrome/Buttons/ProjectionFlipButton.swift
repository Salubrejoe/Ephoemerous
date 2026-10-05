import SwiftUI

// MARK: - ProjectionFlipButton
// Toggles NorthOUT — the celestial-pole-centred perspective: the sky becomes
// a fixed map centred on the South celestial pole with the visible sky
// OUTSIDE the horizon, and the horizon becomes the moving element. Hidden in
// compass mode (the two perspectives are mutually exclusive). Glass circle
// mirrors `CompassModeButton` so the top control cluster reads as one family.
//
// LOOK mode is a projection too, so this button owns it:
//   • chart  — tap flips NorthIN ↔ NorthOUT; LONG-PRESS opens the window.
//   • window — the glyph is a viewfinder in the accent ("live / engaged");
//     a tap is the ONLY way back, to the chart you came from.
// (See `AppState+Look`.)
struct ProjectionFlipButton: View {

    @Environment(AppState.self) private var state

    /// `bare` = no glass of its own — for riding inside the shared camera
    /// capsule, where the container carries the glass and the ENGAGED state
    /// is spoken by the glyph tint (Maps' blue arrow), not a segment fill.
    var bare: Bool = false

    private let haptic   = UIImpactFeedbackGenerator(style: .medium)
    private let faceSize: CGFloat = 44

    /// Hold time (s) that opens the window. ▼ TWEAK ▼
    private let lookPressDuration = 0.5
    /// A long press still ends in a tap when the finger lifts — which, with
    /// the window just opened, would close it again. Swallow that one.
    @State private var swallowTap = false

    var body: some View {
        let looking = state.isLooking
        let on      = state.isNorthOut || looking

        let button = Button {
            if swallowTap { swallowTap = false; return }
            haptic.impactOccurred()
            // Read LIVE, not the `looking` this body captured — a stale
            // capture flipped the projection instead of leaving the window.
            if state.isLooking { state.exitLook() } else { state.toggleSkyPerspective() }
        } label: {
            // A sphere with orbit arrows — "turn the celestial sphere
            // around" — honest about what the toggle does, unlike the old
            // abstract dot-in-ring. Font-sized (not .resizable-stretched)
            // so its stroke weight matches the compass glyph below it.
            // ▼ TWEAK size/weight here (pairs with compass-mode) ▼
            Image(systemName: looking ? "viewfinder" : "rotate.3d")
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 21, weight: .medium))
                .frame(width: faceSize, height: faceSize)
                // Full-face tap target — see CompassModeButton.
                .contentShape(.rect)
                .foregroundStyle(bare ? (on ? Color.accentColor : Color.primary)
                                      : (on ? Color.white       : Color.primary))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: lookPressDuration).onEnded { _ in
                guard !state.isLooking, state.canLook else { return }
                swallowTap = true
                state.enterLook()                   // MainView plays the haptic
            }
        )
        .accessibilityAction(named: Text("Look through the phone")) { state.enterLook() }
        .animation(.snappy(duration: 0.25), value: on)
        .animation(.snappy(duration: 0.25), value: looking)

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

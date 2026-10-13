import SwiftUI

// MARK: - OrlojButton
// Stands the Orloj on the sky, or takes it down (see `OrlojOverlay`).
// Rides the camera capsule above the projection flip, and appears only on
// the NorthOUT chart — the one projection the clock is drawn in.
struct OrlojButton: View {

    @Environment(AppState.self) private var state

    /// `bare` = no glass of its own — for riding inside the shared camera
    /// capsule; the engaged state is spoken by the glyph tint.
    var bare: Bool = false

    private let haptic   = UIImpactFeedbackGenerator(style: .medium)
    private let faceSize: CGFloat = 44

    var body: some View {
        let on = state.isOrlojOn

        let button = Button {
            haptic.impactOccurred()
            state.isOrlojOn.toggle()
        } label: {
            // ▼ TWEAK the glyph here (pairs with the flip) ▼
            Image(systemName: "clock")
                .symbolVariant(on ? .fill : .none)
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 21, weight: .medium))
                .frame(width: faceSize, height: faceSize)
                .contentShape(.rect)
                .foregroundStyle(bare ? (on ? Color.accentColor : Color.primary)
                                      : (on ? Color.white       : Color.primary))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Orloj"))
        .accessibilityValue(Text(on ? "On" : "Off"))
        .animation(.snappy(duration: 0.25), value: on)

        if bare {
            button
        } else {
            button.glassEffect(.regular.tint(on ? Color.accentColor : .clear)
                .interactive(), in: .circle)
        }
    }
}

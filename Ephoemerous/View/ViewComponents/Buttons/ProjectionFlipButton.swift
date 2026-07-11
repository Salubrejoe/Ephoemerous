import SwiftUI

// MARK: - ProjectionFlipButton
// Toggles the inside-out (nadir-centred) projection: the sky turns inside
// out about the horizon — the visible sky moves OUTSIDE the horizon circle
// and the view centres on the far celestial pole. Hidden in compass mode
// (the two perspectives are mutually exclusive). Glass circle mirrors
// `CompassModeButton` so the top control cluster reads as one family.
struct ProjectionFlipButton: View {

    @Environment(EAppState.self) private var state

    private let haptic   = UIImpactFeedbackGenerator(style: .medium)
    private let faceSize: CGFloat = 44

    var body: some View {
        let on = state.flippedProjection

        Button {
            haptic.impactOccurred()
            state.toggleProjectionFlip()
        } label: {
            // A dot inside a ring reads as "sky inside the horizon"; the
            // hollow ring as the flipped "sky outside" perspective.
            Image(systemName: on ? "circle.circle" : "smallcircle.filled.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .frame(width: faceSize, height: faceSize)
                .foregroundStyle(on ? Color.orange : Color.white)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(on ? .orange : .clear).interactive(), in: .circle)
        .animation(.snappy(duration: 0.25), value: on)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        ProjectionFlipButton()
            .environment(EAppState())
    }
}

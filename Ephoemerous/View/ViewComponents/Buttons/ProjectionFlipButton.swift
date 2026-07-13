import SwiftUI

// MARK: - ProjectionFlipButton
// Toggles NorthOUT — the celestial-pole-centred perspective: the sky becomes
// a fixed map centred on the South celestial pole with the visible sky
// OUTSIDE the horizon, and the horizon becomes the moving element. Hidden in
// compass mode (the two perspectives are mutually exclusive). Glass circle
// mirrors `CompassModeButton` so the top control cluster reads as one family.
struct ProjectionFlipButton: View {

    @Environment(EAppState.self) private var state

    private let haptic   = UIImpactFeedbackGenerator(style: .medium)
    private let faceSize: CGFloat = 44

    var body: some View {
        let on = state.isNorthOut

        Button {
            haptic.impactOccurred()
            state.toggleSkyPerspective()
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

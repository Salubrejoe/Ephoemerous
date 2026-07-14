import SwiftUI

// MARK: - CameraClusterCapsule
// The camera-family controls fused into ONE instrument — a vertical glass
// capsule, Apple-Maps style (their transit + locate pill): the perspective
// flip on top, the compass-mode (follow-my-heading, our "locate") below.
// One container instead of two floating circles reads as a single tool;
// the engaged state is spoken by the glyph tint (accent = live), never a
// segment fill.
//
// Lives bottom-trailing, floating just above the search sheet's resting
// bar — thumb territory, since compass mode is toggled while raising the
// phone. Taller sheet detents slide over it (Maps behaviour).
//
// In the Simulator (no gyro) the compass-mode segment self-hides and the
// capsule gracefully shrinks to the flip alone.
struct CameraClusterCapsule: View {

    var body: some View {
        VStack(spacing: 0) {
            ProjectionFlipButton(bare: true)
            CompassModeButton(bare: true)
        }
        .padding(.bottom, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        CameraClusterCapsule()
            .environment(EAppState())
    }
}

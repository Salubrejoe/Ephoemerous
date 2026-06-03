import SwiftUI

// MARK: - CompassButton
// Apple-Maps-style compass. The needle spins with `state.canvasRotation`
// so its red tip always points to where North now sits on the rotated
// sky; tapping springs the canvas back to aligned (0°). Like Maps, it
// fades away when the sky is already upright — there's nothing to reset —
// and fades back in the moment a two-finger twist (or the dev slider)
// knocks it off North.
struct CompassButton: View {

    @Environment(EAppState.self) private var state

    /// Crisp tick on reset — same rigid feel as the rotation detent.
    private let resetHaptic = UIImpactFeedbackGenerator(style: .rigid)

    /// Below this the sky reads as aligned: hide the compass.
    private let alignedEpsilon: Double = 0.5

    var body: some View {
        let aligned = abs(state.canvasRotation.degrees) < alignedEpsilon

        Button {
            resetHaptic.impactOccurred()
            withAnimation(.snappy) { state.canvasRotation = .zero }
        } label: {
            needle
                .rotationEffect(state.canvasRotation)
                .frame(width: 40, height: 40)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        // Auto-hide when upright (Maps behaviour) — nothing to reset.
        .opacity(aligned ? 0 : 1)
        .scaleEffect(aligned ? 0.6 : 1)
        .allowsHitTesting(!aligned)
        .animation(.snappy(duration: 0.3), value: aligned)
    }

    // MARK: - Needle

    /// Two-tone bowtie: red north tip, muted south tail, with a small hub
    /// where they meet. Sized so the pair sits centred in the 40 pt face.
    private var needle: some View {
        VStack(spacing: 0) {
            CompassArrow()
                .fill(.red)
                .frame(width: 9, height: 12)
            CompassArrow()
                .fill(.secondary)
                .rotationEffect(.degrees(180))
                .frame(width: 9, height: 12)
        }
        .overlay {
            Circle()
                .fill(.primary)
                .frame(width: 3, height: 3)
        }
    }
}

// MARK: - CompassArrow
// A simple upward-pointing triangle (apex at top-centre, base along the
// bottom edge). Two of them, one flipped, make the compass needle.
private struct CompassArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        CompassButton()
            .environment({
                let s = EAppState()
                s.canvasRotation = .degrees(35)
                return s
            }())
    }
}

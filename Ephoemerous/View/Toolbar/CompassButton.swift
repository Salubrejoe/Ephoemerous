import SwiftUI

// MARK: - CompassButton
// Apple-Maps-style compass rose. The whole dial — needle + N/E/S/W
// markers — spins with `state.canvasRotation`, so the red north tip and
// the "N" always sit over where North currently lands on the rotated
// sky. The cardinal letters counter-rotate inside the dial so they stay
// upright and readable at any angle. Tapping springs the canvas back to
// aligned (0°) with a settling overshoot. Like Maps, it fades away when
// the sky is already upright — nothing to reset — and fades back in the
// moment a two-finger twist (or any rotation) knocks it off North.
struct CompassButton: View {

    @Environment(EAppState.self) private var state

    /// Crisp tick on reset — same rigid feel as the rotation detent.
    private let resetHaptic = UIImpactFeedbackGenerator(style: .rigid)

    /// Below this the sky reads as aligned: hide the compass.
    private let alignedEpsilon: Double = 0.5
    /// Face diameter and the radius the cardinal letters orbit at.
    private let faceSize:    CGFloat = 46
    private let labelRadius: CGFloat = 16

    var body: some View {
        // Hide only once settled at North AND no spin-back is in flight —
        // so the compass stays on screen to play the bouncy reset rather
        // than fading out the instant it's tapped.
        let aligned = abs(state.canvasRotation.degrees) < alignedEpsilon
            && state._rotationTransition == nil

        Button {
            resetHaptic.impactOccurred()
            // Bouncy spin-back to North. Driven through a canvas
            // transition (not withAnimation) so the *sky* animates too —
            // both the dial and the Canvas snapshot read `renderedRotation`.
            state.animateRotation(to: .zero)
        } label: {
            dial
                .frame(width: faceSize, height: faceSize)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(CompassPressStyle())
        // Auto-hide when upright (Maps behaviour) — nothing to reset.
        .opacity(aligned ? 0 : 1)
        .scaleEffect(aligned ? 0.6 : 1)
        .allowsHitTesting(!aligned)
        .animation(.snappy(duration: 0.3), value: aligned)
    }

    // MARK: - Dial

    /// Needle + cardinal rose, rotated as one by `renderedRotation` — the
    /// interpolated value, so the dial rides the bouncy reset in lock-step
    /// with the sky (both read the same source).
    private var dial: some View {
        ZStack {
            cardinals
            needle
        }
        .rotationEffect(-state.renderedRotation)
    }

    /// Two-tone bowtie: red north tip, muted south tail, with a small hub
    /// where they meet.
    private var needle: some View {
        VStack(spacing: 0) {
            CompassArrow()
                .fill(.orange)
                .frame(width: 8, height: 11)
            CompassArrow()
                .fill(.secondary)
                .rotationEffect(.degrees(180))
                .frame(width: 8, height: 11)
        }
    }

    // MARK: - Cardinal letters

    /// N / E / S / W placed at the four edges. Each is counter-rotated by
    /// `-canvasRotation` so, once the parent dial spins by `+canvasRotation`,
    /// the glyph nets back to upright while its *position* still orbits —
    /// "N" rides over the red needle tip, the rest follow 90° apart.
    private var cardinals: some View {
        ZStack {
            cardinal("N", color: .orange,       dx: 0,            dy: -labelRadius)
            cardinal("E", color: .secondary, dx:  labelRadius, dy: 0)
            cardinal("S", color: .secondary, dx: 0,            dy:  labelRadius)
            cardinal("W", color: .secondary, dx: -labelRadius, dy: 0)
        }
    }

    private func cardinal(_ letter: String, color: Color,
                          dx: CGFloat, dy: CGFloat) -> some View {
        Text(letter)
            .font(.system(size: 8, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .rotationEffect(state.renderedRotation)   // keep upright
            .offset(x: dx, y: dy)
    }
}

// MARK: - CompassPressStyle
// Springy shrink on press so the tap feels physical before the needle
// flies home.
private struct CompassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.84 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5),
                       value: configuration.isPressed)
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

import SwiftUI
import LoreKit

// MARK: - CompassButton
// Squircle compass chip. Pared back from the four-letter rose to two
// moving parts:
//
//   • a single orange DOT that rides the perimeter where North currently
//     lands on the rotated sky (the old needle's north tip, set free), and
//   • one CENTRAL letter naming whichever cardinal is nearest the top of
//     the screen — i.e. the direction you're currently facing "up".
//
// When North is up the dot sits at the top and the letter reads "N"; as
// the sky rotates (two-finger twist, or compass mode following the phone)
// the dot orbits and the letter swaps to the nearest cardinal. Tapping
// springs the canvas back to North (and drops compass mode). Like Maps it
// fades away when the sky is already upright — unless compass mode is on,
// where it stays as a live heading readout.
//
// E/W run the SKY way here (East left of North), matching the
// inside-the-dome projection — see `EProjection` / `cardinalAtTop`.
struct CompassButton: View {

    @Environment(EAppState.self) private var state

    /// Crisp tick on reset — same rigid feel as the rotation detent.
    private let resetHaptic = UIImpactFeedbackGenerator(style: .rigid)

    /// Below this the sky reads as aligned: hide the compass.
    private let alignedEpsilon: Double = 0.5

    // Circular face (matches the heading-up toggle's diameter) +
    // orbiting-dot geometry.
//    private let faceSize:    CGFloat = 37
    private let faceSize:    CGFloat = 46
    private let roseCorners: Int     = 12
    private let roseBulge:   CGFloat = 2.5
    private let orbitRadius: CGFloat = 17
//    private let orbitRadius: CGFloat = 16
    private let dotSize:     CGFloat = 9
//    private let dotSize:     CGFloat = 6

    private var roseShape: Squircle { Squircle(corners: roseCorners, bulge: roseBulge) }

    var body: some View {
        // Hide only once settled at North AND no spin-back is in flight —
        // so the chip stays on screen to play the bouncy reset rather than
        // fading out the instant it's tapped. In compass mode it's never
        // "aligned": the dot is a live heading readout, always shown.
        let aligned = !state.compassMode
            && abs(state.renderedRotation.degrees) < alignedEpsilon
            && state._rotationTransition == nil

        if !aligned {
            Button {
                resetHaptic.impactOccurred()
                // Bouncy spin-back to North — and drop out of compass mode if
                // it was on. Driven through a canvas transition (not
                // withAnimation) so the *sky* animates too; both the dial and
                // the Canvas snapshot read `renderedRotation`.
                state.resetRotationToNorth()
            } label: {
                centralLetter
                    .frame(width: faceSize, height: faceSize)
                // Plain ultra-thin material circle — it sits inside the
                // search sheet's own glass, so no glass-on-glass. Matches
                // the heading-up toggle's circle.
                
            }
            //        .buttonStyle(CompassPressStyle())
            .buttonStyle(.plain)
            .contentShape(roseShape)
            .glassEffect(.regular.interactive(), in: roseShape)
            // Auto-hide when upright (Maps behaviour) — nothing to reset.
            .scaleEffect(aligned ? 0.6 : 1)
            .allowsHitTesting(!aligned)
            .animation(.snappy(duration: 0.3), value: aligned)
            .overlay {
                orbitingDot
                    .rotationEffect(-state.renderedRotation)
            }
            //        .opacity(aligned ? 0 : 1)
            // Collapse to zero width when hidden so it leaves no gap in a
            // horizontal layout (the SearchSheet header) — not just invisible.
        }
    }


    /// The cardinal nearest the top, dead centre and always upright.
    private var centralLetter: some View {
        Text(cardinalAtTop)
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(.primary)
//            .rotationEffect(state.renderedRotation)
            .contentTransition(.opacity)
            .animation(.snappy(duration: 0.2), value: cardinalAtTop)
            
    }

    /// Orange dot marking North's screen position. Pinned at the top, then
    /// rotated by `-renderedRotation` so it orbits the centre exactly where
    /// the old needle's north tip pointed — interpolated value, so it rides
    /// the bouncy reset in lock-step with the sky.
    private var orbitingDot: some View {
//        Image(systemName: "location.north.fill")
//            .resizable()
//            .scaledToFit()
        Text("N")
            .font(.system(size: dotSize))
            .fontWeight(.heavy)
            .foregroundStyle(Color.accentColor)
            .offset(y: -orbitRadius)
    }

    // MARK: - Cardinal readout

    /// The cardinal letter closest to the top of the screen for the
    /// current rotation. North's screen bearing (clockwise from up) is
    /// `-renderedRotation`; on the inside-the-dome / E-left sky map the
    /// clockwise order from North is N → W → S → E. The one whose bearing
    /// is nearest 0 (straight up) wins — so at rest it reads "N".
    private var cardinalAtTop: String {
        let r = state.renderedRotation.degrees
        let candidates: [(String, Double)] = [
            ("N", -r),
            ("W", -r + 90),
            ("S", -r + 180),
            ("E", -r + 270),
        ]
        return candidates.min {
            angularDistance($0.1) < angularDistance($1.1)
        }!.0
    }

    /// Absolute angle from straight-up, folded into [0°, 180°].
    private func angularDistance(_ degrees: Double) -> Double {
        var x = degrees.truncatingRemainder(dividingBy: 360)
        if x >  180 { x -= 360 }
        if x < -180 { x += 360 }
        return abs(x)
    }
}

// MARK: - CompassPressStyle
// Springy shrink on press so the tap feels physical before the dot
// flies home.
private struct CompassPressStyle: ButtonStyle {
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
        CompassButton()
            .environment({
                let s = EAppState()
                s.canvasRotation = .degrees(134)
                return s
            }())
    }
}

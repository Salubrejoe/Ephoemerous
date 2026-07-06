import SwiftUI
import LoreKit

// MARK: - DetailActionRow
// Paired action row for the constellation / star detail header.
// Two pills that swap their roles when the object is remembered.
//
//   State A — NOT remembered:
//     [○ book]  [──── Remember ────────]
//     LearnMyth: circular, regular material, just the book symbol
//                tinted the cycle's accent.
//     Remember:  capsule, `.glassProminent` button style, white
//                "Remember" — the primary call to action.
//
//   State B — REMEMBERED:
//     [──── tagline ────]  [○ ♥]
//     LearnMyth: capsule, regular material, book symbol + the
//                cycle's tagline (e.g. "The hunter and the
//                scorpion"). Accent lives only in the symbol +
//                label; the surface stays neutral so it doesn't
//                shout once the primary action is done.
//     Remember:  circular, regular material, pink heart — uses the
//                SF Symbol replace + wiggle effects so the heart
//                first appears empty inside the new circle, then
//                fills, then wiggles. Tapping it returns to
//                State A.
//
// Layout note: this is intentionally NOT inside a
// GlassEffectContainer. An earlier draft nested glass pills inside
// a glass container ("glass on glass"), and the doubled blur read
// as heavy when the rest of the detail sheet is already a clear
// surface. Regular material + glassProminent gives the same
// hierarchy with much less visual weight.
//
// `.none` myths render the bare `RememberButton` instead — no
// secondary action to pair with, so the row stays a simple
// primary in those cases (Lacaille / Bayer / Hevelius and the
// stars in them).

struct DetailActionRow: View {
    let obj:         ESkyObject

    @Environment(EAppState.self) var state

    /// Drives `Image(systemName:)` between `heart` and `heart.fill`.
    /// Separate from `remembered` because we deliberately delay the
    /// fill until AFTER the shape swap has settled — so the user
    /// sees the empty heart appear inside the new circle first,
    /// then watches it fill, then watches it wiggle.
    @State private var heartFilled:   Bool = false

    /// Toggled to fire `.symbolEffect(.wiggle, value:)`. Separate
    /// from `heartFilled` so the wiggle is its own beat, after the
    /// fill — not simultaneous with it.
    @State private var wiggleTrigger: Bool = false

    /// Tracks whether the next `onChange(initial:)` firing is the
    /// view's first appearance vs a real user toggle. Lets us skip
    /// the reveal-sequence when the user reopens an already-
    /// remembered object.
    @State private var isInitialAppearance: Bool = true

    /// Namespace for `matchedGeometryEffect`. Without it the
    /// if/else swap below is two separate view trees — the old pill
    /// removes, the new pill inserts at its target size, and the
    /// width snaps. With matched IDs linking learnMyth↔learnMyth
    /// and remember↔remember, SwiftUI interpolates the frame
    /// between the two variants so the morph reads as a single
    /// pill reshaping (cf. Apple's tabbar / search field morphs).
    @Namespace private var morphNS

    private var remembered: Bool { state.isFavourite(obj) }
//    private var accent:     Color { EArtist.shared.constellationMythGradient(myth).top }

    /// Fixed row height for every pill in every state. Widths morph
    /// between circular (== height) and "fills the rest of the row";
    /// the height never changes, so the surrounding layout doesn't
    /// twitch on each favourite toggle.
    private let pillHeight: CGFloat = 50

    // MARK: Body

    var body: some View {
        HStack(spacing: 8) {
            if remembered {
                rememberHeart
                    .matchedGeometryEffect(id: "remember",  in: morphNS)
            } else {
                rememberPrimary
                    .matchedGeometryEffect(id: "remember",  in: morphNS)
            }
        }
        .frame(height: pillHeight)
        .animation(.bouncy,
                   value: remembered)
        // Sequence the symbol animations behind the state swap:
        //   t = 0       : remembered flips → row swaps content
        //   t = ~280 ms : heart fills (replace symbol effect)
        //   t = ~460 ms : heart wiggles
        // `initial: true` so first-appearance of an already-
        // remembered object renders pre-filled without replaying
        // the reveal animation.
        .onChange(of: remembered, initial: true) { _, new in
            guard new else { heartFilled = false; return }
            if !heartFilled && isInitialAppearance {
                heartFilled         = true
                isInitialAppearance = false
                return
            }
            heartFilled = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                heartFilled = true
                try? await Task.sleep(for: .milliseconds(180))
                wiggleTrigger.toggle()
            }
        }
    }

    

    // MARK: Remember — State A (prominent capsule, primary)

    private var rememberPrimary: some View {
        Button {
            state.toggleFavourite(obj)
        } label: {
            Text(String(localized: "Remember"))
                .foregroundStyle(.white)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.capsule)
                .glassEffect(.clear.tint(.accentColor).interactive(), in: .capsule)
        }
        .transition(.blurReplace.combined(with: .opacity))
    }

    // MARK: Remember — State B (minimal circle, heart)

    private var rememberHeart: some View {
        Button {
            state.toggleFavourite(obj)
        } label: {
            // `heartFilled` is the visible state — driven by the
            // post-swap delay above, NOT directly by `remembered`.
            // That's how we get the "empty → fill → wiggle" beat.
            Image(symbol: heartFilled ? .heartFill : .heart)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.pink)
                .contentTransition(.symbolEffect(.replace.downUp))
                .symbolEffect(.wiggle,
                              options: .nonRepeating,
                              value:   wiggleTrigger)
                .frame(width: pillHeight, height: pillHeight)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .transition(.blurReplace.combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview("Orion star") {
    DetailActionRow(obj: .star(EStar.mockStars[0]))
    .padding()
    .environment(EAppState())
}

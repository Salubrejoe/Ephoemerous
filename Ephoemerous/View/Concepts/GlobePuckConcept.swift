import SwiftUI

// MARK: - GlobePuck (concept)
// The Apple-Maps "you are here" puck reimagined as a little globe:
// the classic white ring + tinted disc, with the real
// `globe.europe.africa.fill` SF Symbol hugging the disc. The globe
// carries a white outline that merges into the puck ring, so symbol
// + puck read as a single mark.
//
// Concept only — not wired into any layer. See the previews below
// for the tint pairings under evaluation (white/blue, green/blue,
// white/green) at both hero and home-screen sizes.
struct GlobePuck: View {

    var disc:   Color
    var symbol: Color
    var ring:   Color   = .white
    var size:   CGFloat = 120

    /// Coloured-disc diameter as a fraction of the whole puck — the
    /// remainder is the white ring (mirrors the app puck's 6 / 8).
    private var discFraction:  CGFloat { 1 }
    /// Globe diameter as a fraction of the disc — ~1 so the rim
    /// hugs the ring rather than floating in the middle.
    private var globeFraction: CGFloat { 1 }
    /// White outline around the globe, as a fraction of its size —
    /// the "symbol border" that matches the puck's white ring.
    private var borderFraction: CGFloat { 0.0 }

    private var discSize:  CGFloat { size * discFraction }
    private var globeSize: CGFloat { discSize * globeFraction }

    var body: some View {
        ZStack {
            Circle().fill(ring)
            Circle().fill(disc).frame(width: discSize, height: discSize)
            globe
        }
        .frame(width: size, height: size)
    }

    // White underlay (grown) + tinted overlay → a uniform white edge
    // around every filled landmass and the globe rim.
    private var globe: some View {
        ZStack {
            glyph(grownBy: borderFraction * globeSize, color: ring)
            glyph(grownBy: 0,                          color: symbol)
        }
    }

    private func glyph(grownBy grow: CGFloat, color: Color) -> some View {
        Image(systemName: "globe.europe.africa")
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: globeSize + grow, height: globeSize + grow)
    }
}

// MARK: - Previews

#Preview("Globe puck — tint pairings") {
    VStack(spacing: 48) {
        HStack(spacing: 44) {
            GlobePuck(disc: .blue,  symbol: .white)
            GlobePuck(disc: .white,  symbol: .green)
            GlobePuck(disc: .green, symbol: .white)
        }
        // Home-screen-scale legibility check.
        HStack(spacing: 28) {
            GlobePuck(disc: .blue,  symbol: .white, size: 44)
            GlobePuck(disc: .white,  symbol: .green, size: 44)
            GlobePuck(disc: .green, symbol: .white, size: 44)
        }
    }
    .padding(48)
    .background(Color(white: 0.12))
}

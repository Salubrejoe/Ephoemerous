import SwiftUI
import LoreKit

// MARK: - SquircleGlobePuck (concept 2)
// The globe puck, but wearing the app's signature horizon silhouette
// instead of a circle: a 12-corner, bulge-2.2 `Squircle`
// (LoreKit/Squircle.swift — the same Lamé curve the horizon rim
// rides). The globe is clipped to that same scallop, so its rim
// ripples in sympathy and the "you are here" dot becomes a tiny
// horizon medallion.
//
// Concept only. Previews compare it head-to-head with the circular
// puck at hero + home-screen sizes.
struct SquircleGlobePuck: View {

    var disc:       Color
    var symbol:     Color
    var ring:       Color   = .systemBackground
    var size:       CGFloat = 120
    /// SF Symbol used as the globe glyph. Defaults to the
    /// Europe/Africa hemisphere — the production call site
    /// (`UserLocationPuck`) overrides this with the symbol that
    /// matches the observer's longitude so a user in Sydney sees
    /// `globe.asia.australia.fill`, a user in São Paulo sees
    /// `globe.americas.fill`, etc.
    var symbolName: String  = "globe.europe.africa.fill"

    /// Horizon-rim Lamé parameters — kept in sync with
    /// `EArtist.horizonBumpCorners` / `horizonBumpBulge`.
    private var corners: Int     { 12 }
    private var bulge:   CGFloat { 2.2 }

    /// White border thickness as a fraction of the puck — the ring
    /// traces the scallop instead of a clean circle.
    private var ringFraction:  CGFloat { 0.08 }
    /// Globe diameter as a fraction of the puck — slightly under 1 so
    /// the scallop bites the globe rim rather than the bumps poking
    /// past it.
    private var globeFraction: CGFloat { 0.99 }

    private var scallop:   Squircle { Squircle(corners: corners, bulge: bulge) }
    private var globeSize: CGFloat  { size * globeFraction }
    private var ringInset: CGFloat  { size * ringFraction }

    var body: some View {
        ZStack {
            scallop.fill(ring)
            scallop.fill(disc).padding(ringInset)
            globe
                .frame(width: globeSize, height: globeSize)
                .clipShape(scallop)
        }
        .frame(width: size, height: size)
    }

    // White underlay (grown) + tinted overlay → a uniform white edge
    // around every landmass; both share the scallop clip above.
    private var globe: some View {
        ZStack {
            glyph(grownBy: globeSize * 0.06, color: ring)
            glyph(grownBy: 0,                color: symbol)
        }
    }

    private func glyph(grownBy grow: CGFloat, color: Color) -> some View {
        Image(systemName: symbolName)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color.opacity(0.8))
            .frame(width: globeSize + grow, height: globeSize + grow)
    }
}

// MARK: - Previews

#Preview("Current Choice") {
    VStack(spacing: 48) {
        SquircleGlobePuck(disc: .blue,  symbol: .white)
        SquircleGlobePuck(disc: .blue,  symbol: .white, size: 44)
    }
}
#Preview("Squircle globe puck — tint pairings") {
    VStack(spacing: 48) {
        HStack(spacing: 44) {
            SquircleGlobePuck(disc: .blue,  symbol: .white)
            SquircleGlobePuck(disc: .white, symbol: .green)
            SquircleGlobePuck(disc: .green, symbol: .white)
        }
        HStack(spacing: 28) {
            SquircleGlobePuck(disc: .blue,  symbol: .white, size: 44)
            SquircleGlobePuck(disc: .white, symbol: .green, size: 44)
            SquircleGlobePuck(disc: .green, symbol: .white, size: 44)
        }
    }
    .padding(48)
    .background(Color(white: 0.12))
}

#Preview("Circle vs scallop") {
    VStack(spacing: 40) {
        HStack(spacing: 44) {
            GlobePuck(disc: .blue, symbol: .white)
            SquircleGlobePuck(disc: .blue, symbol: .white)
        }
        HStack(spacing: 28) {
            GlobePuck(disc: .blue, symbol: .white, size: 44)
            SquircleGlobePuck(disc: .blue, symbol: .white, size: 44)
        }
    }
    .padding(48)
    .background(Color(white: 0.12))
}

import SwiftUI
import LoreKit

// MARK: - Color (project palette)
// The app's brand palette + a handful of back-compat aliases.
//
// Generic colour plumbing (`Color(hex:)`, the UIColor-system role
// wrappers like `.label`, `.systemRed`, `.tertiarySystemBackground`)
// lives in LoreKit's `Color+Hex.swift` / `Color+System.swift`. This
// file holds only the project-specific values — the palette of named
// brand colours and the aliases that prefer one role over another.
extension Color {

    // MARK: Base palette
    static let baseOrange   = Color(hex: "#D3801E")
    static let baseCoral    = Color(hex: "#D65D53")
    static let baseRose     = Color(hex: "#B55179")
    static let basePlum     = Color(hex: "#7D5487")
    static let baseIndigo   = Color(hex: "#475279")
    static let baseSlate    = Color.tertiarySystemBackground

    // MARK: Matching gradient stops
    static let gradOrange    = Color(hex: "#D3801E")
    static let gradOlive     = Color(hex: "#A28600")
    static let gradGreenTeal = Color(hex: "#070870")
    static let gradForest    = Color(hex: "#37832A")
    static let gradGreen     = Color(hex: "#007B46")
    static let gradEmerald   = Color(hex: "#007160")

    // MARK: Spot palette
    static let spotOrange   = Color(hex: "#D3801E")
    static let spotClay     = Color(hex: "#805934")
    static let spotCream    = Color(hex: "#FFEACD")
    static let spotNavy     = Color(hex: "#005247")

    // MARK: Back-compat aliases — keep the existing names that resolve
    // to LoreKit's system colours. Saves a project-wide rename.
    static let sysBackground = Color.systemBackground
    static let tertiary      = Color.tertiaryLabel
}

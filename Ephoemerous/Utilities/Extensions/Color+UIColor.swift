import SwiftUI
import LoreKit

// MARK: - Color (project palette)
// A handful of back-compat aliases. (The old base / gradient / spot brand
// palette is retired — see `DeprecationStation/RetiredColors`.)
//
// Generic colour plumbing (`Color(hex:)`, the UIColor-system role
// wrappers like `.label`, `.systemRed`, `.tertiarySystemBackground`)
// lives in LoreKit's `Color+Hex.swift` / `Color+System.swift`. This
// file holds only the project-specific aliases that prefer one role over another.
extension Color {

    // MARK: Back-compat aliases — keep the existing names that resolve
    // to LoreKit's system colours. Saves a project-wide rename.
    static let sysBackground = Color.systemBackground
    static let tertiary      = Color.tertiaryLabel
}

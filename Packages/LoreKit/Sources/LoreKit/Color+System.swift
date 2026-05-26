#if canImport(UIKit)

import SwiftUI
import UIKit

// MARK: - SwiftUI Color ⇄ UIColor system roles
// SwiftUI ships a handful of semantic colours (`.primary`, `.secondary`)
// but the full UIKit role palette (`.label`, `.secondaryLabel`,
// `.systemFill`, the grouped backgrounds, the system reds/oranges…)
// only lives on `UIColor`. These wrappers expose each one as a
// SwiftUI `Color` so calling code can stay on the SwiftUI side.
//
// iOS-gated — `Color(uiColor:)` and the underlying `UIColor` statics
// don't exist on macOS. LoreKit still compiles there; this file just
// contributes nothing.
public extension Color {

    // MARK: Label
    static let label              = Color(uiColor: .label)
    static let secondaryLabel     = Color(uiColor: .secondaryLabel)
    static let tertiaryLabel      = Color(uiColor: .tertiaryLabel)
    static let quaternaryLabel    = Color(uiColor: .quaternaryLabel)

    // MARK: Fills
    static let systemFill             = Color(uiColor: .systemFill)
    static let secondarySystemFill    = Color(uiColor: .secondarySystemFill)
    static let tertiarySystemFill     = Color(uiColor: .tertiarySystemFill)
    static let quaternarySystemFill   = Color(uiColor: .quaternarySystemFill)

    // MARK: Text field / link
    static let placeholderText    = Color(uiColor: .placeholderText)
    static let link               = Color(uiColor: .link)

    // MARK: Separators
    static let separator          = Color(uiColor: .separator)
    static let opaqueSeparator    = Color(uiColor: .opaqueSeparator)

    // MARK: Backgrounds
    static let systemBackground           = Color(uiColor: .systemBackground)
    static let secondarySystemBackground  = Color(uiColor: .secondarySystemBackground)
    static let tertiarySystemBackground   = Color(uiColor: .tertiarySystemBackground)

    static let systemGroupedBackground           = Color(uiColor: .systemGroupedBackground)
    static let secondarySystemGroupedBackground  = Color(uiColor: .secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBackground   = Color(uiColor: .tertiarySystemGroupedBackground)

    // MARK: System palette
    static let systemRed     = Color(uiColor: .systemRed)
    static let systemOrange  = Color(uiColor: .systemOrange)
    static let systemYellow  = Color(uiColor: .systemYellow)
    static let systemGreen   = Color(uiColor: .systemGreen)
    static let systemMint    = Color(uiColor: .systemMint)
    static let systemTeal    = Color(uiColor: .systemTeal)
    static let systemCyan    = Color(uiColor: .systemCyan)
    static let systemBlue    = Color(uiColor: .systemBlue)
    static let systemIndigo  = Color(uiColor: .systemIndigo)
    static let systemPurple  = Color(uiColor: .systemPurple)
    static let systemPink    = Color(uiColor: .systemPink)
    static let systemBrown   = Color(uiColor: .systemBrown)
    static let systemGray    = Color(uiColor: .systemGray)

    static let systemGray2   = Color(uiColor: .systemGray2)
    static let systemGray3   = Color(uiColor: .systemGray3)
    static let systemGray4   = Color(uiColor: .systemGray4)
    static let systemGray5   = Color(uiColor: .systemGray5)
    static let systemGray6   = Color(uiColor: .systemGray6)

    // MARK: Tint
    static let tint          = Color(uiColor: .tintColor)
}

#endif

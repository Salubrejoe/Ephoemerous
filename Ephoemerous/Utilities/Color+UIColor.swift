import SwiftUI

extension Color {
    
    /// Initialize a Color from a hex integer (e.g. 0xFF9900) with optional alpha (0...1)
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8)  / 255.0
        let b = Double( hex & 0x0000FF)        / 255.0
        self = Color(red: r, green: g, blue: b, opacity: alpha)
    }

    /// Initialize a Color from hex strings like "#RRGGBB", "RRGGBB", "#RRGGBBAA", or "RRGGBBAA".
    /// Falls back to clear if parsing fails.
    init(hex string: String) {
        // Remove leading '#' and whitespace
        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        var hexValue: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&hexValue) else {
            self = .clear
            return
        }

        switch cleaned.count {
        case 6: // RRGGBB
            let r = Double((hexValue & 0xFF0000) >> 16) / 255.0
            let g = Double((hexValue & 0x00FF00) >> 8)  / 255.0
            let b = Double( hexValue & 0x0000FF)        / 255.0
            self = Color(red: r, green: g, blue: b)
        case 8: // RRGGBBAA
            let r = Double((hexValue & 0xFF000000) >> 24) / 255.0
            let g = Double((hexValue & 0x00FF0000) >> 16) / 255.0
            let b = Double((hexValue & 0x0000FF00) >> 8)  / 255.0
            let a = Double( hexValue & 0x000000FF)       / 255.0
            self = Color(red: r, green: g, blue: b, opacity: a)
        default:
            self = .clear
        }
    }
    
    // MARK: - Label Colors
    static let label              = Color(uiColor: .label)
    static let secondaryLabel     = Color(uiColor: .secondaryLabel)
    static let tertiaryLabel      = Color(uiColor: .tertiaryLabel)
    static let quaternaryLabel    = Color(uiColor: .quaternaryLabel)

    // MARK: - Fill Colors
    static let systemFill             = Color(uiColor: .systemFill)
    static let secondarySystemFill    = Color(uiColor: .secondarySystemFill)
    static let tertiarySystemFill     = Color(uiColor: .tertiarySystemFill)
    static let quaternarySystemFill   = Color(uiColor: .quaternarySystemFill)

    // MARK: - Text Field Colors
    static let placeholderText    = Color(uiColor: .placeholderText)

    // MARK: - Standard Content Colors
    static let link               = Color(uiColor: .link)

    // MARK: - Separator Colors
    static let separator          = Color(uiColor: .separator)
    static let opaqueSeparator    = Color(uiColor: .opaqueSeparator)

    // MARK: - Background Colors
    static let systemBackground           = Color(uiColor: .systemBackground)
    static let secondarySystemBackground  = Color(uiColor: .secondarySystemBackground)
    static let tertiarySystemBackground   = Color(uiColor: .tertiarySystemBackground)

    // MARK: - Grouped Background Colors
    static let systemGroupedBackground           = Color(uiColor: .systemGroupedBackground)
    static let secondarySystemGroupedBackground  = Color(uiColor: .secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBackground   = Color(uiColor: .tertiarySystemGroupedBackground)

    // MARK: - System Colors
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

    // MARK: - Grays
    static let systemGray2   = Color(uiColor: .systemGray2)
    static let systemGray3   = Color(uiColor: .systemGray3)
    static let systemGray4   = Color(uiColor: .systemGray4)
    static let systemGray5   = Color(uiColor: .systemGray5)
    static let systemGray6   = Color(uiColor: .systemGray6)

    // MARK: - Tint
    static let tint          = Color(uiColor: .tintColor)

    // Backwards-compat convenience aliases (keep existing names)
    static let sysBackground = Color(uiColor: .systemBackground)
    static let tertiary      = Color(uiColor: .tertiaryLabel)
    
    // MARK: - Custom Palette

    // Base Palette
    static let baseOrange   = Color(hex: "#D3801E")
    static let baseCoral    = Color(hex: "#D65D53")
    static let baseRose     = Color(hex: "#B55179")
    static let basePlum     = Color(hex: "#7D5487")
    static let baseIndigo   = Color(hex: "#475279")
    static let baseSlate    = Color(hex: "#2F4858")

    // Matching Gradient
    static let gradOrange   = Color(hex: "#D3801E")
    static let gradOlive    = Color(hex: "#A28600")
    static let gradGreenTeal = Color(hex: "#070870")
    static let gradForest   = Color(hex: "#37832A")
    static let gradGreen    = Color(hex: "#007B46")
    static let gradEmerald  = Color(hex: "#007160")

    // Spot Palette
    static let spotOrange   = Color(hex: "#D3801E")
    static let spotClay     = Color(hex: "#805934")
    static let spotCream    = Color(hex: "#FFEACD")
    static let spotNavy     = Color(hex: "#005247")
}

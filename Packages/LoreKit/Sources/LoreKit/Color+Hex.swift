import SwiftUI

// MARK: - Color hex initializers
// Hex-int + hex-string inits for SwiftUI `Color`. Cross-platform; no
// UIKit/AppKit. The string init parses "#RRGGBB", "RRGGBB",
// "#RRGGBBAA", or "RRGGBBAA"; anything else falls back to `.clear`
// rather than crashing on a typo.
public extension Color {

    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >>  8) / 255.0
        let b = Double( hex & 0x0000FF)        / 255.0
        self = Color(red: r, green: g, blue: b, opacity: alpha)
    }

    init(hex string: String) {
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
            let g = Double((hexValue & 0x00FF00) >>  8) / 255.0
            let b = Double( hexValue & 0x0000FF)        / 255.0
            self = Color(red: r, green: g, blue: b)
        case 8: // RRGGBBAA
            let r = Double((hexValue & 0xFF000000) >> 24) / 255.0
            let g = Double((hexValue & 0x00FF0000) >> 16) / 255.0
            let b = Double((hexValue & 0x0000FF00) >>  8) / 255.0
            let a = Double( hexValue & 0x000000FF)        / 255.0
            self = Color(red: r, green: g, blue: b, opacity: a)
        default:
            self = .clear
        }
    }
}

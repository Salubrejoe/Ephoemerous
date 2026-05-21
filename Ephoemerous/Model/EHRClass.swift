import SwiftUI

enum EHRClass: String, CaseIterable {

    case O, B, A, F, G, K, M, unknown

    // MARK: - Dark-mode colours (bright pastels, high visibility on dark sky)
    var color: Color {
        switch self {
        case .O:       Color(red: 0.6,  green: 0.7,  blue: 1.0)   // Blue
        case .B:       Color(red: 0.7,  green: 0.8,  blue: 1.0)   // Blue-white
        case .A:       Color(red: AstroConstants.specA_blue, green: AstroConstants.specA_green, blue: 1.0)  // White
        case .F:       Color(red: 1.0,  green: 1.0,  blue: AstroConstants.specF_blue)  // Yellow-white
        case .G:       Color(red: 1.0,  green: 1.0,  blue: 0.8)   // Yellow
        case .K:       Color(red: 1.0,  green: AstroConstants.specK_green, blue: 0.6)  // Orange
        case .M:       Color(red: 1.0,  green: 0.7,  blue: 0.5)   // Red
        case .unknown: Color.gray
        }
    }

    // MARK: - Light-mode colours (deep & saturated, high contrast on white)
    var lightColor: Color {
        switch self {
        case .O:       Color(red: 0.10, green: 0.25, blue: 0.80)   // Deep cobalt
        case .B:       Color(red: 0.22, green: 0.42, blue: 0.85)   // Royal blue
        case .A:       Color(red: 0.30, green: 0.50, blue: 0.75)   // Steel blue
        case .F:       Color(red: 0.68, green: 0.58, blue: 0.05)   // Warm gold
        case .G:       Color(red: 0.72, green: 0.55, blue: 0.00)   // Deep amber
        case .K:       Color(red: 0.80, green: 0.36, blue: 0.05)   // Burnt orange
        case .M:       Color(red: 0.76, green: 0.15, blue: 0.10)   // Deep crimson
        case .unknown: Color(white: 0.38)
        }
    }

    // MARK: - Adaptive helper
    func adaptiveColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color : lightColor
    }
}

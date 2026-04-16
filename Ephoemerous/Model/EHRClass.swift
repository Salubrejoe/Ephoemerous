
import SwiftUI


enum EHRClass: String, CaseIterable {
  
  case O, B, A, F, G, K, M, unknown
  
  var color: Color {
    switch self {
    case .O: Color(red: 0.6, green: 0.7, blue: 1.0)   // Blue
    case .B: Color(red: 0.7, green: 0.8, blue: 1.0)   // Blue-white
    case .A: Color(red: 0.85, green: 0.9, blue: 1.0)  // White
    case .F: Color(red: 1.0, green: 1.0, blue: 0.95)  // Yellow-white
    case .G: Color(red: 1.0, green: 1.0, blue: 0.8)   // Yellow
    case .K: Color(red: 1.0, green: 0.85, blue: 0.6)  // Orange
    case .M: Color(red: 1.0, green: 0.7, blue: 0.5)   // Red
    case .unknown: Color.gray
    }
  }
}

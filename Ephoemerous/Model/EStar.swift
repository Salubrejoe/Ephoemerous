
import SwiftUI


struct EStar: Identifiable {
  let id = UUID()
  
  let name           : String
  let rightAscension : Angle
  let declination    : Angle
  let magnitude      : Double
  let spectralClass  : EHRClass
  let pmRA           : Double
  let pmDE           : Double
  
  private static let greekLetterMap: [String: String] = [
    "Alp": "α",
    "Bet": "β",
    "Gam": "γ",
    "Del": "δ",
    "Eps": "ε",
    
    "Zet": "ζ",
    "Eta": "η",
    "The": "θ",
    "Iot": "ι",
    "Kap": "κ",
    
    "Lam": "λ",
    "Mu" : "μ",
    "Nu" : "ν",
    "Xi" : "ξ",
    "Omi": "ο",
    
    "Pi" : "π",
    "Rho": "ρ",
    "Sig": "σ",
    "Tau": "τ",
    "Ups": "υ",
    
    "Phi": "φ",
    "Chi": "χ",
    "Psi": "ψ",
    "Ome": "ω"
  ]
  
  init(from starData: StarData) {
    self.name           = EStar.calculateName(from: starData)
    self.rightAscension = EStar.calculateRA(from: starData)
    self.declination    = EStar.calculateDec(from: starData)
    self.magnitude      = EStar.calculateMagnitude(from: starData)
    self.spectralClass  = EStar.calculateSpectralClass(from: starData)
    self.pmRA           = EStar.calculateProperMotionRA(from: starData)
    self.pmDE           = EStar.calculateProperMotionDec(from: starData)
  }
  
  var constellation: EConstellation {
    let components = name.components(separatedBy: " ")
    if let abbrev = components.last, let constellation = EConstellation(rawValue: abbrev) {
      return constellation
    }
    return .none
  }
}

private extension EStar {
  
  static func calculateName(from starData: StarData) -> String {
    guard var name = starData.name else { return "Unknown" }
    
    // Replace numbers with superscript
    name = name
      .replacingOccurrences(of: "1", with: "")
      .replacingOccurrences(of: "2", with: "")
      .replacingOccurrences(of: "3", with: "")
      .replacingOccurrences(of: "4", with: "")
      .replacingOccurrences(of: "5", with: "")
      .replacingOccurrences(of: "6", with: "")
      .replacingOccurrences(of: "7", with: "")
      .replacingOccurrences(of: "8", with: "")
      .replacingOccurrences(of: "9", with: "")
      .replacingOccurrences(of: "0", with: "")
    
    //     Replace Greek letters with Unicode characters
    
    
    let last3Char = String(name.suffix(3))
    name = name.replacingOccurrences(of: last3Char, with: "").trimmingCharacters(in: .whitespaces)
    
    for (spelling, symbol) in EStar.greekLetterMap {
      name = name.replacingOccurrences(of: spelling, with: "\(symbol) ")
    }
    
    if let constellation = EConstellation(rawValue: last3Char) {
      name = name + constellation.rawValue
    }
    
    return name
  }
  
  static func calculateRA(from starData: StarData) -> Angle {
    let hours   = Double(starData.rightAscensionHours) ?? 0
    let minutes = Double(starData.rightAscensionMinutes) ?? 0
    let seconds = Double(starData.rightAscensionSeconds) ?? 0
    return .init(hours: hours, minutes: minutes, seconds: seconds)
  }
  
  static func calculateDec(from starData: StarData) -> Angle {
    let sign = (starData.declinationSign.starts(with: "-") ? -1.0 : 1.0)
    let degrees = Double(starData.declinationDegrees) ?? 0
    let minutes = Double(starData.declinationMinutes) ?? 0
    let seconds = Double(starData.declinationSeconds) ?? 0
    let totalDegrees = sign * (degrees + (minutes / 60) + (seconds / 3600))
    return .degrees(totalDegrees)
  }
  
  static func calculateMagnitude(from starData: StarData) -> Double {
    Double(starData.magnitude) ?? 0
  }
  
  static func calculateSpectralClass(from starData: StarData) -> EHRClass {
    EHRClass(rawValue: String(starData.spectralClass.prefix(1))) ?? .G
  }
  
  static func calculateProperMotionRA(from starData: StarData) -> Double {
    Double(starData.pmRA) ?? 0
  }
  
  static func calculateProperMotionDec(from starData: StarData) -> Double {
    Double(starData.pmDE) ?? 0
  }
}

extension EStar {
  static let mockStars: [EStar] = [
    EStar(from: StarData(name: "Alp Ori", rightAscensionHours: "5", rightAscensionMinutes: "55", rightAscensionSeconds: "10", declinationSign: "-", declinationDegrees: "7", declinationMinutes: "24", declinationSeconds: "25", magnitude: "0.42", spectralClass: "M", pmRA: "-3.2", pmDE: "2.3")),
    EStar(from: StarData(name: "Bet CMa", rightAscensionHours: "6", rightAscensionMinutes: "45", rightAscensionSeconds: "9", declinationSign: "-", declinationDegrees: "16", declinationMinutes: "42", declinationSeconds: "58", magnitude: "-1.46", spectralClass: "A", pmRA: "-7.3", pmDE: "3.6")),
    EStar(from: StarData(name: "Gam Leo", rightAscensionHours: "10", rightAscensionMinutes: "19", rightAscensionSeconds: "59", declinationSign: "+", declinationDegrees: "19", declinationMinutes: "50", declinationSeconds: "29", magnitude: "2.61", spectralClass: "K", pmRA: "-1.5", pmDE: "0.7"))
  ]
}



/*
 ¹
 ²
 ³
 ⁴
 ⁵
 ⁶
 ⁷
 ⁸
 ⁹
 ⁰
 */

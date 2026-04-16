
import Foundation


struct StarData: Codable {
  let name                  : String?
  let rightAscensionHours   : String
  let rightAscensionMinutes : String
  let rightAscensionSeconds : String
  let declinationSign       : String
  let declinationDegrees    : String
  let declinationMinutes    : String
  let declinationSeconds    : String
  let magnitude             : String
  let spectralClass         : String
  let pmRA                  : String
  let pmDE                  : String
  
  enum CodingKeys: String, CodingKey {
    case name                  = "Name"
    case rightAscensionHours   = "RAh"
    case rightAscensionMinutes = "RAm"
    case rightAscensionSeconds = "RAs"
    case declinationSign       = "DE-"
    case declinationDegrees    = "DEd"
    case declinationMinutes    = "DEm"
    case declinationSeconds    = "DEs"
    case magnitude             = "Vmag"
    case spectralClass         = "SpType"
    case pmRA
    case pmDE
  }
}

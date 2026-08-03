
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

  // MARK: Companions
  // BSC5's double / multiple-star columns. All optional — most stars carry
  // none of them, and a star can have a separation without a detection
  // flag (or the reverse). Parsed into `EStarMultiplicity`, which is where
  // the meaning lives; here we only carry the raw strings.
  /// Detection method: W = visual double (Worley), S = spectroscopic,
  /// A = astrometric, D = occultation duplicity, I = Innes, R = other.
  var multipleFlag          : String? = nil
  /// Component identifier within the system, e.g. "AB", "AP".
  var multipleID            : String? = nil
  /// Number of components in the system.
  var multipleCount         : String? = nil
  /// Separation between the two brightest components, ARCSECONDS.
  var separation            : String? = nil
  /// Magnitude difference between those components.
  var magnitudeDifference   : String? = nil
  /// Aitken Double Star catalogue number — the system's shared identifier.
  var adsNumber             : String? = nil

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
    case multipleFlag          = "Multiple"
    case multipleID            = "MultID"
    case multipleCount         = "MultCnt"
    case separation            = "Sep"
    case magnitudeDifference   = "Dmag"
    case adsNumber             = "ADS"
  }
}


import SwiftUI


enum EConstellation: String, CaseIterable {
  
  case none
  case And
  case Ant
  case Aps
  case Aqr
  case Aql
  case Ara
  case Ari
  case Aur
  case Boo
  case Cae
  case Cam
  case Cap
  case Car
  case Cas
  case Cen
  case Cep
  case Cet
  case Cha
  case Cir
  case CMa
  case CMi
  case Cnc
  case Col
  case Com
  case CrA
  case CrB
  case Crt
  case Cru
  case Crv
  case CVn
  case Cyg
  case Del
  case Dor
  case Dra
  case Equ
  case Eri
  case For
  case Gem
  case Gru
  case Her
  case Hor
  case Hya
  case Hyi
  case Ind
  case Lac
  case Leo
  case Lep
  case Lib
  case LMi
  case Lup
  case Lyn
  case Lyr
  case Men
  case Mic
  case Mon
  case Mus
  case Nor
  case Oct
  case Oph
  case Ori
  case Pav
  case Peg
  case Per
  case Phe
  case Pic
  case PsA
  case Psc
  case Pup
  case Pyx
  case Ret
  case Sco
  case Scl
  case Sct
  case Ser
  case Sex
  case Sge
  case Sgr
  case Tau
  case Tel
  case TrA
  case Tri
  case Tuc
  case UMa
  case UMi
  case Vel
  case Vir
  case Vol
  case Vul
  
  var genitive: String {
    switch self {
    case .And: "Andromedae"
    case .Aqr: "Aquarii"
    case .Aql: "Aquilae"
    case .Ari: "Arietis"
    case .Aur: "Aurigae"
    case .Boo: "Boötis"
    case .Cnc: "Cancri"
    case .CMa: "Canis Majoris"
    case .CMi: "Canis Minoris"
    case .Cap: "Capricorni"
    case .Cas: "Cassiopeiae"
    case .Cep: "Cephei"
    case .Cet: "Ceti"
    case .Cyg: "Cygni"
    case .Gem: "Geminorum"
    case .Leo: "Leonis"
    case .Lib: "Librae"
    case .Lyr: "Lyrae"
    case .Oph: "Ophiuchi"
    case .Ori: "Orionis"
    case .Peg: "Pegasi"
    case .Per: "Persei"
    case .Psc: "Piscium"
    case .Sgr: "Sagittarii"
    case .Tau: "Tauri"
    case .UMa: "Ursae Majoris"
    case .UMi: "Ursae Minoris"
    case .Vir: "Virginis"
    default: self.rawValue
    }
  }
  
  var fullName: String {
    switch self {
    case .none : "None"
    case .And : "Andromeda"
    case .Ant : "Antlia"
    case .Aps : "Apus"
    case .Aqr : "Aquarius"
    case .Aql : "Aquila"
    case .Ara : "Ara"
    case .Ari : "Aries"
    case .Aur : "Auriga"
    case .Boo : "Boötes"
    case .Cae : "Caelum"
    case .Cam : "Camelopardus"
    case .Cap : "Capricornus"
    case .Car : "Carina"
    case .Cas : "Cassiopeia"
    case .Cen : "Centaurus"
    case .Cep : "Cepheus"
    case .Cet : "Cetus"
    case .Cha : "Chamaeleon"
    case .Cir : "Circinus"
    case .CMa : "Canis Major"
    case .CMi : "Canis Minor"
    case .Cnc : "Cancer"
    case .Col : "Columba"
    case .Com : "Coma Berenice"
    case .CrA : "Corona Australis"
    case .CrB : "Corona Borealis"
    case .Crt : "Crater"
    case .Cru : "Crux"
    case .Crv : "Corvus"
    case .CVn : "Canes Venatici"
    case .Cyg : "Cygnus"
    case .Del : "Delphinus"
    case .Dor : "Dorado"
    case .Dra : "Draco"
    case .Equ : "Equuleus"
    case .Eri : "Eridanus"
    case .For : "Fornax"
    case .Gem : "Gemini"
    case .Gru : "Grus"
    case .Her : "Hercules"
    case .Hor : "Horologium"
    case .Hya : "Hydra"
    case .Hyi : "Hydrus"
    case .Ind : "Indus"
    case .Lac : "Lacerta"
    case .Leo : "Leo"
    case .Lep : "Lepus"
    case .Lib : "Libra"
    case .LMi : "Leo Minor"
    case .Lup : "Lupus"
    case .Lyn : "Lynx"
    case .Lyr : "Lyra"
    case .Men : "Mensa"
    case .Mic : "Microscopium"
    case .Mon : "Monoceros"
    case .Mus : "Musca"
    case .Nor : "Norma"
    case .Oct : "Octans"
    case .Oph : "Ophiuchus"
    case .Ori : "Orion"
    case .Pav : "Pavo"
    case .Peg : "Pegasus"
    case .Per : "Perseus"
    case .Phe : "Phoenix"
    case .Pic : "Pictor"
    case .PsA : "Piscis Austrinus"
    case .Psc : "Pisces"
    case .Pup : "Puppis"
    case .Pyx : "Pyxis"
    case .Ret : "Reticulum"
    case .Sco : "Scorpius"
    case .Scl : "Sculptor"
    case .Sct : "Scutum"
    case .Ser : "Serpens"
    case .Sex : "Sextans"
    case .Sge : "Sagitta"
    case .Sgr : "Sagittarius"
    case .Tau : "Taurus"
    case .Tel : "Telescopium"
    case .TrA : "Triangulum Australe"
    case .Tri : "Triangulum"
    case .Tuc : "Tucana"
    case .UMa : "Ursa Major"
    case .UMi : "Ursa Minor"
    case .Vel : "Vela"
    case .Vir : "Virgo"
    case .Vol : "Volans"
    case .Vul : "Vulpecula"
    }
  }
  
  var isZodiacSign: Bool {
    switch self {
    case .Ari, .Cnc, .Cap, .Gem, .Psc, .Vir, .Lib, .Aqr, .Sgr, .Tau, .Leo, .Sco : true
    default: false
    }
  }
  
  var isCool: Bool {
    switch self {
    case .Ari, .Boo, .Cep, .Cyg, .CMa, .CMi, .Ori, .Per, .Aur, .And, .Cnc, .Cap, .Gem, .Psc, .Vir, .Lib, .Aqr, .Sgr, .Tau, .Leo, .Sco, .UMa, .UMi, .Cas : true
    default: false
    }
  }
  
  public var stars: [EStar] {
    StarDatabase.shared.workableStars.filter {
      $0.constellation.rawValue == self.rawValue
    }.filter {
      $0.declination.degrees <= 30
    }
  }
  
  public var indexedStars: [EStar] {
    let greekLetters = Set(["α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ", "λ", "μ", "ν", "ξ", "ο", "π", "ρ", "σ", "τ", "υ", "φ", "χ", "ψ", "ω"])
    return stars.filter { greekLetters.contains(String($0.name.prefix(1)))
    }
  }
  
  func visibleStars(cutoff magnitude: Double) -> [EStar] {
    stars.filter { $0.magnitude < magnitude }
  }
}


extension EConstellation {
  
  static var zodiacIndexedStars: [EStar] {
    var result = [EStar]()
    for constellation in EConstellation.allCases {
      if constellation.isZodiacSign {
        result += constellation.indexedStars
      }
    }
    return result
  }
  
  static func visibleZodiacStars(cutoff magnitude: Double = 10) -> [EStar] {
    var result = [EStar]()
    for constellation in EConstellation.allCases {
      if constellation.isZodiacSign {
        result += constellation.visibleStars(cutoff: magnitude)
      }
    }
    return result
  }
  
  static func visibleStars(cutoff magnitude: Double = 10) -> [EStar] {
    var result = [EStar]()
    for constellation in EConstellation.allCases {
      if constellation.isCool {
        result += constellation.visibleStars(cutoff: magnitude)
      }
    }
    return result
  }
}


/*
 { "ADS": "46", "B-V": "+0.07", "DE-": "+", "DE-1900": "+", "DEd": "45", "DEd1900": "44", "DEm": "13", "DEm1900": "40", "DEs": "45", "DEs1900": "22", "DM": "BD+44 4550", "Dmag": "4.2", "GLAT": "-16.88", "GLON": "114.44", "HD": "3", "HR": "1", "MultCnt": "3", "MultID": "AC", "RAh": "00", "RAh1900": "00", "RAm": "05", "RAm1900": "00", "RAs": "09.9", "RAs1900": "01.1", "RadVel": "-018", "RotVel": "195", "SAO": "36042", "Sep": "21.6", "SpType": "A1Vn", "U-B": "+0.08", "Vmag": "6.70", "pmDE": "-0.018", "pmRA": "-0.012" },
 { "B-V": "+1.10", "DE-": "-", "DE-1900": "-", "DEd": "00", "DEd1900": "01", "DEm": "30", "DEm1900": "03", "DEs": "11", "DEs1900": "30", "DM": "BD-01 4525", "GLAT": "-61.14", "GLON": "98.33", "HD": "6", "HR": "2", "RAh": "00", "RAh1900": "23", "RAm": "05", "RAm1900": "59", "RAs": "03.8", "RAs1900": "56.2", "RadVel": "+014", "SAO": "128569", "SpType": "gG9", "U-B": "+1.02", "Vmag": "6.29", "n_RadVel": "V", "pmDE": "-0.060", "pmRA": "+0.045" },
 { "B-V": "+1.04", "DE-": "-", "DE-1900": "-", "DEd": "05", "DEd1900": "06", "DEm": "42", "DEm1900": "16", "DEs": "27", "DEs1900": "01", "DM": "BD-06 6357", "Dmag": "2.5", "FK5": "1002", "GLAT": "-65.93", "GLON": "93.75", "HD": "28", "HR": "3", "IRflag": "I", "MultCnt": "3", "Name": "33 Psc", "NoteFlag": "*", "Parallax": "+.014", "R-I": "+0.54", "RAh": "00", "RAh1900": "00", "RAm": "05", "RAm1900": "00", "RAs": "20.1", "RAs1900": "13.0", "RadVel": "-006", "RotVel": "17", "SAO": "128572", "Sep": "0.0", "SpType": "K0IIIbCN-0.5", "U-B": "+0.89", "VarID": "Var?", "Vmag": "4.61", "l_RotVel": "<", "n_RadVel": "SB1O", "pmDE": "+0.089", "pmRA": "-0.009" },
 { "B-V": "+0.90", "DE-": "+", "DE-1900": "+", "DEd": "13", "DEd1900": "12", "DEm": "23", "DEm1900": "50", "DEs": "46", "DEs1900": "23", "DM": "BD+12 5063", "FK5": "2004", "GLAT": "-47.98", "GLON": "106.19", "HD": "87", "HR": "4", "Name": "86 Peg", "RAh": "00", "RAh1900": "00", "RAm": "05", "RAm1900": "00", "RAs": "42.0", "RAs1900": "33.8", "RadVel": "-002", "SAO": "91701", "SpType": "G5III", "Vmag": "5.51", "n_RadVel": "V?", "pmDE": "-0.012", "pmRA": "+0.045" },
 { "ADS": "61", "B-V": "+0.67", "DE-": "+", "DE-1900": "+", "DEd": "58", "DEd1900": "57", "DEm": "26", "DEm1900": "52", "DEs": "12", "DEs1900": "45", "DM": "BD+57 2865", "Dmag": "0.8", "GLAT": "-03.92", "GLON": "117.03", "HD": "123", "HR": "5", "NoteFlag": "*", "Parallax": "+.047", "RAh": "00", "RAh1900": "00", "RAm": "06", "RAm1900": "01", "RAs": "16.0", "RAs1900": "01.8", "RadVel": "-012", "SAO": "21085", "Sep": "1.4", "SpType": "G5V", "U-B": "+0.20", "VarID": "V640 Cas", "Vmag": "5.96", "n_RadVel": "V", "pmDE": "+0.030", "pmRA": "+0.263" },
 { "B-V": "+0.52", "DE-": "-", "DE-1900": "-", "DEd": "49", "DEd1900": "49", "DEm": "04", "DEm1900": "37", "DEs": "30", "DEs1900": "51", "DM": "CD-4914337", "Dmag": "5.7", "GLAT": "-66.38", "GLON": "321.61", "HD": "142", "HR": "6", "Multiple": "W", "NoteFlag": "*", "Parallax": "+.050", "RAh": "00", "RAh1900": "00", "RAm": "06", "RAm1900": "01", "RAs": "19.0", "RAs1900": "08.4", "RadVel": "+003", "SAO": "214963", "Sep": "5.4", "SpType": "G1IV", "U-B": "+0.05", "Vmag": "5.70", "n_RadVel": "SB", "pmDE": "-0.038", "pmRA": "+0.565" },
 { "B-V": "-0.03", "DE-": "+", "DE-1900": "+", "DEd": "64", "DEd1900": "63", "DEm": "11", "DEm1900": "38", "DEs": "46", "DEs1900": "22", "DM": "BD+63 2107", "FK5": "2005", "GLAT": "1.75", "GLON": "118.06", "HD": "144", "HR": "7", "Name": "10 Cas", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "06", "RAm1900": "01", "RAs": "26.5", "RAs1900": "14.4", "RadVel": "-000", "RotVel": "153", "SAO": "10978", "SpType": "B9III", "U-B": "-0.19", "Vmag": "5.59", "n_RadVel": "V", "n_SpType": "e", "pmDE": "0.000", "pmRA": "+0.008" },
 { "ADS": "69", "B-V": "+0.75", "DE-": "+", "DE-1900": "+", "DEd": "29", "DEd1900": "28", "DEm": "01", "DEm1900": "28", "DEs": "17", "DEs1900": "11", "DM": "BD+28 4704", "Dmag": "2.6", "GLAT": "-32.83", "GLON": "111.26", "HD": "166", "HR": "8", "MultCnt": "4", "MultID": "AB", "NoteFlag": "*", "Parallax": "+.067", "RAh": "00", "RAh1900": "00", "RAm": "06", "RAm1900": "01", "RAs": "36.8", "RAs1900": "25.2", "RadVel": "-008", "SAO": "73743", "Sep": "158.6", "SpType": "K0V", "U-B": "+0.33", "VarID": "33", "Vmag": "6.13", "n_RadVel": "V", "pmDE": "-0.182", "pmRA": "+0.380" },
 { "B-V": "+0.38", "DE-": "-", "DE-1900": "-", "DEd": "23", "DEd1900": "23", "DEm": "06", "DEm1900": "39", "DEs": "27", "DEs1900": "47", "DM": "CD-23 4", "FK5": "1003", "GLAT": "-79.14", "GLON": "52.21", "HD": "203", "HR": "9", "RAh": "00", "RAh1900": "00", "RAm": "06", "RAm1900": "01", "RAs": "50.1", "RAs1900": "43.0", "RadVel": "+003", "SAO": "166053", "SpType": "A7V", "U-B": "+0.05", "Vmag": "6.18", "n_RadVel": "V", "pmDE": "-0.045", "pmRA": "+0.100" },
 { "B-V": "+0.14", "DE-": "-", "DE-1900": "-", "DEd": "17", "DEd1900": "17", "DEm": "23", "DEm1900": "56", "DEs": "11", "DEs1900": "39", "DM": "BD-18 6428", "GLAT": "-75.90", "GLON": "74.36", "HD": "256", "HR": "10", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "07", "RAm1900": "02", "RAs": "18.2", "RAs1900": "11.8", "RadVel": "-009", "RotVel": "195", "SAO": "147090", "SpType": "A6Vn", "U-B": "+0.10", "Vmag": "6.19", "n_RadVel": "V?", "pmDE": "+0.036", "pmRA": "-0.018" },
 { "B-V": "-0.14", "DE-": "-", "DE-1900": "-", "DEd": "02", "DEd1900": "03", "DEm": "32", "DEm1900": "06", "DEs": "56", "DEs1900": "20", "DM": "BD-03 2", "GLAT": "-63.29", "GLON": "98.02", "HD": "315", "HR": "11", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "07", "RAm1900": "02", "RAs": "44.1", "RAs1900": "36.7", "RadVel": "+013", "SAO": "128595", "SpType": "B8IIIpSi", "U-B": "-0.47", "VarID": "Var?", "Vmag": "6.43", "pmDE": "-0.002", "pmRA": "+0.027" },
 { "ADS": "89", "B-V": "+0.14", "DE-": "-", "DE-1900": "-", "DEd": "22", "DEd1900": "23", "DEm": "30", "DEm1900": "03", "DEs": "32", "DEs1900": "52", "DM": "CD-23 13", "Dmag": "5.1", "GLAT": "-79.07", "GLON": "55.56", "HD": "319", "HR": "12", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "07", "RAm1900": "02", "RAs": "46.8", "RAs1900": "40.3", "RadVel": "-013", "SAO": "166066", "Sep": "1.9", "SpType": "A2Vp:", "U-B": "+0.06", "VarID": "46", "Vmag": "5.94", "n_RadVel": "V", "pmDE": "-0.044", "pmRA": "+0.052" },
 { "B-V": "+1.12", "DE-": "-", "DE-1900": "-", "DEd": "33", "DEd1900": "34", "DEm": "31", "DEm1900": "05", "DEs": "46", "DEs1900": "10", "DM": "CD-34 17", "GLAT": "-78.67", "GLON": "355.91", "HD": "344", "HR": "13", "RAh": "00", "RAh1900": "00", "RAm": "08", "RAm1900": "02", "RAs": "03.5", "RAs1900": "58.6", "RadVel": "+007", "SAO": "192367", "SpType": "K1III", "Vmag": "5.68", "pmDE": "0.000", "pmRA": "-0.037" },
 { "B-V": "+1.38", "DE-": "-", "DE-1900": "-", "DEd": "02", "DEd1900": "03", "DEm": "26", "DEm1900": "00", "DEs": "52", "DEs1900": "15", "DM": "BD-03 3", "Dmag": "2.0", "FK5": "2006", "GLAT": "-63.24", "GLON": "98.34", "HD": "352", "HR": "14", "IRflag": "I", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "08", "RAm1900": "03", "RAs": "12.1", "RAs1900": "04.8", "RadVel": "+001", "RotVel": "22", "SAO": "128602", "Sep": "0.0", "SpType": "K2III+F", "U-B": "+1.14", "VarID": "AP Psc", "Vmag": "6.07", "n_RadVel": "SB1O", "pmDE": "-0.003", "pmRA": "+0.009" },
 { "ADS": "94", "B-V": "-0.11", "DE-": "+", "DE-1900": "+", "DEd": "29", "DEd1900": "28", "DEm": "05", "DEm1900": "32", "DEs": "26", "DEs1900": "18", "DM": "BD+28 4", "Dmag": "8.5", "FK5": "1", "GLAT": "-32.84", "GLON": "111.73", "HD": "358", "HR": "15", "IRflag": "I", "Name": "21Alp And", "NoteFlag": "*", "Parallax": "+.032", "R-I": "-0.10", "RAh": "00", "RAh1900": "00", "RAm": "08", "RAm1900": "03", "RAs": "23.3", "RAs1900": "13.0", "RadVel": "-012", "RotVel": "56", "SAO": "73765", "Sep": "81.5", "SpType": "B8IVpMnHg", "U-B": "-0.46", "VarID": "Alp And", "Vmag": "2.06", "n_RadVel": "SBO", "n_SpType": "v", "pmDE": "-0.163", "pmRA": "+0.136" },
 { "B-V": "+1.04", "DE-": "-", "DE-1900": "-", "DEd": "08", "DEd1900": "09", "DEm": "49", "DEm1900": "22", "DEs": "26", "DEs1900": "47", "DM": "BD-09 5", "GLAT": "-69.04", "GLON": "91.79", "HD": "360", "HR": "16", "RAh": "00", "RAh1900": "00", "RAm": "08", "RAm1900": "03", "RAs": "17.4", "RAs1900": "10.9", "RadVel": "+020", "SAO": "128604", "SpType": "gG8", "U-B": "+0.83", "Vmag": "5.99", "pmDE": "-0.033", "pmRA": "-0.052" },
 { "B-V": "+0.48", "DE-": "+", "DE-1900": "+", "DEd": "36", "DEd1900": "36", "DEm": "37", "DEm1900": "04", "DEs": "36", "DEs1900": "26", "DM": "BD+35 8", "GLAT": "-25.45", "GLON": "113.45", "HD": "400", "HR": "17", "Parallax": "+.044", "RAh": "00", "RAh1900": "00", "RAm": "08", "RAm1900": "03", "RAs": "41.0", "RAs1900": "31.9", "RadVel": "-014", "RotVel": "6", "SAO": "53677", "SpType": "F8IV", "U-B": "-0.09", "Vmag": "6.19", "l_RotVel": "=<", "pmDE": "-0.145", "pmRA": "-0.100" },
 { "B-V": "+1.67", "DE-": "-", "DE-1900": "-", "DEd": "17", "DEd1900": "18", "DEm": "34", "DEm1900": "08", "DEs": "39", "DEs1900": "01", "DM": "BD-18 3", "GLAT": "-76.25", "GLON": "74.69", "HD": "402", "HR": "18", "IRflag": "I", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "08", "RAm1900": "03", "RAs": "33.4", "RAs1900": "27.1", "RadVel": "-017", "SAO": "147103", "SpType": "M0III", "U-B": "+1.97", "VarID": "51", "Vmag": "6.06", "n_RadVel": "V?", "pmDE": "-0.025", "pmRA": "0.000" },
 { "B-V": "+0.97", "DE-": "+", "DE-1900": "+", "DEd": "25", "DEd1900": "24", "DEm": "27", "DEm1900": "54", "DEs": "46", "DEs1900": "19", "DM": "BD+24 3", "GLAT": "-36.42", "GLON": "110.97", "HD": "417", "HR": "19", "RAh": "00", "RAh1900": "00", "RAm": "08", "RAm1900": "03", "RAs": "52.2", "RAs1900": "42.2", "RadVel": "+015", "SAO": "73769", "SpType": "K0III", "U-B": "+0.73", "Vmag": "6.23", "pmDE": "+0.031", "pmRA": "+0.114" },
 { "ADS": "102", "B-V": "+0.19", "DE-": "+", "DE-1900": "+", "DEd": "79", "DEd1900": "79", "DEm": "42", "DEm1900": "09", "DEs": "53", "DEs1900": "33", "DM": "BD+78 1", "Dmag": "0.2", "GLAT": "17.00", "GLON": "120.98", "HD": "431", "HR": "20", "NoteFlag": "*", "Parallax": "+.002", "RAh": "00", "RAh1900": "00", "RAm": "09", "RAm1900": "03", "RAs": "20.2", "RAs1900": "48.5", "RadVel": "+001", "RotVel": "90", "SAO": "4048", "Sep": "0.6", "SpType": "A7IV", "U-B": "+0.10", "Vmag": "6.01", "pmDE": "-0.027", "pmRA": "+0.102" },
 { "ADS": "107", "B-V": "+0.34", "DE-": "+", "DE-1900": "+", "DEd": "59", "DEd1900": "58", "DEm": "08", "DEm1900": "35", "DEs": "59", "DEs1900": "54", "DM": "BD+58 3", "Dmag": "11.3", "FK5": "2", "GLAT": "-03.27", "GLON": "117.52", "HD": "432", "HR": "21", "IRflag": "I", "Name": "11Bet Cas", "NoteFlag": "*", "Parallax": "+.072", "R-I": "+0.20", "RAh": "00", "RAh1900": "00", "RAm": "09", "RAm1900": "03", "RAs": "10.7", "RAs1900": "50.2", "RadVel": "+012", "RotVel": "70", "SAO": "21133", "Sep": "31.3", "SpType": "F2III-IV", "U-B": "+0.11", "VarID": "Bet Cas", "Vmag": "2.27", "n_RadVel": "SB", "pmDE": "-0.181", "pmRA": "+0.525" },
 { "B-V": "+1.04", "DE-": "+", "DE-1900": "+", "DEd": "18", "DEd1900": "17", "DEm": "12", "DEm1900": "39", "DEs": "43", "DEs1900": "22", "DM": "BD+17 7", "GLAT": "-43.51", "GLON": "108.99", "HD": "448", "HR": "22", "Name": "87 Peg", "RAh": "00", "RAh1900": "00", "RAm": "09", "RAm1900": "03", "RAs": "02.4", "RAs1900": "52.8", "RadVel": "-023", "SAO": "91734", "SpType": "G9III", "Vmag": "5.53", "n_RadVel": "V?", "pmDE": "-0.024", "pmRA": "+0.137" },
 { "B-V": "+0.74", "DE-": "-", "DE-1900": "-", "DEd": "54", "DEd1900": "54", "DEm": "00", "DEm1900": "33", "DEs": "07", "DEs1900": "33", "DM": "CP-54 19", "Dmag": "1.3", "GLAT": "-62.02", "GLON": "316.25", "HD": "469", "HR": "23", "Multiple": "W", "NoteFlag": "*", "Parallax": "+.009", "RAh": "00", "RAh1900": "00", "RAm": "09", "RAm1900": "03", "RAs": "02.4", "RAs1900": "59.7", "RadVel": "+001", "SAO": "231943", "Sep": "0.2", "SpType": "G4IV", "U-B": "+0.39", "Vmag": "6.33", "n_Parallax": "D", "n_RadVel": "SB", "pmDE": "+0.016", "pmRA": "+0.051" },
 { "ADS": "111", "B-V": "+0.42", "DE-": "-", "DE-1900": "-", "DEd": "27", "DEd1900": "28", "DEm": "59", "DEm1900": "32", "DEs": "16", "DEs1900": "40", "DM": "CD-28 16", "Dmag": "0.2", "GLAT": "-80.63", "GLON": "25.24", "HD": "493", "HR": "24", "MultCnt": "3", "MultID": "AB", "Name": "Kap1Scl", "NoteFlag": "*", "Parallax": "+.023", "RAh": "00", "RAh1900": "00", "RAm": "09", "RAm1900": "04", "RAs": "21.0", "RAs1900": "15.2", "RadVel": "+009", "RotVel": "131", "SAO": "166083", "Sep": "1.4", "SpType": "F2V", "U-B": "+0.08", "Vmag": "5.42", "pmDE": "-0.004", "pmRA": "+0.072" },
 { "B-V": "+1.03", "DE-": "-", "DE-1900": "-", "DEd": "45", "DEd1900": "46", "DEm": "44", "DEm1900": "17", "DEs": "51", "DEs1900": "57", "DM": "CD-46 18", "FK5": "3", "GLAT": "-69.60", "GLON": "324.34", "HD": "496", "HR": "25", "Name": "Eps Phe", "Parallax": "+.066", "R-I": "+0.52", "RAh": "00", "RAh1900": "00", "RAm": "09", "RAm1900": "04", "RAs": "24.7", "RAs1900": "20.2", "RadVel": "-009", "SAO": "214983", "SpType": "K0III", "U-B": "+0.84", "Vmag": "3.88", "pmDE": "-0.181", "pmRA": "+0.124" },
 { "ADS": "122", "B-V": "-0.07", "DE-": "+", "DE-1900": "+", "DEd": "11", "DEd1900": "10", "DEm": "08", "DEm1900": "35", "DEs": "44", "DEs1900": "21", "DM": "BD+10 8", "Dmag": "4.4", "GLAT": "-50.43", "GLON": "106.87", "HD": "560", "HR": "26", "Name": "34 Psc", "NoteFlag": "*", "Parallax": "+.017", "RAh": "00", "RAh1900": "00", "RAm": "10", "RAm1900": "04", "RAs": "02.3", "RAs1900": "53.8", "RadVel": "+014", "RotVel": "275", "SAO": "91750", "Sep": "7.7", "SpType": "B9Vn", "U-B": "-0.24", "Vmag": "5.51", "n_Parallax": "D", "n_RadVel": "V", "n_SpType": "e", "pmDE": "-0.003", "pmRA": "+0.041" },
 { "B-V": "+0.40", "DE-": "+", "DE-1900": "+", "DEd": "46", "DEd1900": "45", "DEm": "04", "DEm1900": "30", "DEs": "20", "DEs1900": "57", "DM": "BD+45 17", "FK5": "4", "GLAT": "-16.21", "GLON": "115.52", "HD": "571", "HR": "27", "Name": "22 And", "NoteFlag": "*", "Parallax": "-.002", "R-I": "+0.29", "RAh": "00", "RAh1900": "00", "RAm": "10", "RAm1900": "05", "RAs": "19.3", "RAs1900": "07.2", "RadVel": "-005", "RotVel": "47", "SAO": "36123", "SpType": "F2II", "U-B": "+0.25", "Vmag": "5.03", "pmDE": "0.000", "pmRA": "+0.008" },
 { "B-V": "-0.08", "DE-": "+", "DE-1900": "+", "DEd": "57", "DEd1900": "56", "DEm": "09", "DEm1900": "36", "DEs": "56", "DEs1900": "32", "DM": "BD+56 11", "GLAT": "-05.26", "GLON": "117.38", "HD": "584", "HR": "28", "RAh": "00", "RAh1900": "00", "RAm": "10", "RAm1900": "05", "RAs": "29.7", "RAs1900": "15.0", "RadVel": "+002", "SAO": "21162", "SpType": "B7IV", "U-B": "-0.41", "Vmag": "6.74", "pmDE": "+0.006", "pmRA": "+0.023" },
 { "B-V": "+0.98", "DE-": "-", "DE-1900": "-", "DEd": "05", "DEd1900": "05", "DEm": "14", "DEm1900": "48", "DEs": "55", "DEs1900": "15", "DM": "BD-06 11", "GLAT": "-66.03", "GLON": "96.99", "HD": "587", "HR": "29", "Multiple": "D", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "10", "RAm1900": "05", "RAs": "18.8", "RAs1900": "11.6", "RadVel": "+024", "SAO": "128621", "SpType": "K1III", "U-B": "+0.74", "Vmag": "5.84", "pmDE": "-0.033", "pmRA": "+0.036" },
 { "B-V": "+1.05", "DE-": "-", "DE-1900": "-", "DEd": "82", "DEd1900": "82", "DEm": "13", "DEm1900": "46", "DEs": "26", "DEs1900": "48", "DM": "CP-82 4", "FK5": "3971", "GLAT": "-34.77", "GLON": "304.63", "HD": "636", "HR": "30", "Name": "Gam3Oct", "RAh": "00", "RAh1900": "00", "RAm": "10", "RAm1900": "05", "RAs": "02.1", "RAs1900": "30.4", "RadVel": "+015", "SAO": "258215", "SpType": "G8III", "U-B": "+0.92", "Vmag": "5.28", "pmDE": "-0.020", "pmRA": "-0.029" },
 { "B-V": "+1.01", "DE-": "-", "DE-1900": "-", "DEd": "12", "DEd1900": "13", "DEm": "34", "DEm1900": "08", "DEs": "48", "DEs1900": "07", "DM": "BD-13 13", "FK5": "2008", "GLAT": "-72.60", "GLON": "87.69", "HD": "645", "HR": "31", "RAh": "00", "RAh1900": "00", "RAm": "10", "RAm1900": "05", "RAs": "42.8", "RAs1900": "35.5", "RadVel": "+006", "SAO": "147127", "SpType": "K0IV", "U-B": "+0.80", "Vmag": "5.85", "n_RadVel": "V?", "pmDE": "-0.038", "pmRA": "+0.150" },
 { "B-V": "+0.37", "DE-": "-", "DE-1900": "-", "DEd": "73", "DEd1900": "73", "DEm": "13", "DEm1900": "46", "DEs": "28", "DEs1900": "53", "DM": "CP-73 4", "Dmag": "1.1", "GLAT": "-43.58", "GLON": "306.98", "HD": "661", "HR": "32", "MultCnt": "3", "MultID": "AB", "Multiple": "W", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "10", "RAm1900": "05", "RAs": "38.6", "RAs1900": "44.4", "RadVel": "-014", "SAO": "255642", "Sep": "0.5", "SpType": "F2V+F6V", "U-B": "+0.06", "Vmag": "6.64", "pmDE": "+0.016", "pmRA": "+0.123" },
 { "B-V": "+0.49", "DE-": "-", "DE-1900": "-", "DEd": "15", "DEd1900": "16", "DEm": "28", "DEm1900": "01", "DEs": "05", "DEs1900": "01", "DM": "BD-16 17", "GLAT": "-75.06", "GLON": "82.24", "HD": "693", "HR": "33", "Name": "6 Cet", "Parallax": "+.067", "RAh": "00", "RAh1900": "00", "RAm": "11", "RAm1900": "06", "RAs": "15.9", "RAs1900": "10.5", "RadVel": "+014", "RotVel": "0", "SAO": "147133", "SpType": "F7V", "U-B": "-0.03", "Vmag": "4.89", "n_RadVel": "V?", "pmDE": "-0.268", "pmRA": "-0.077" },
 { "B-V": "+1.34", "DE-": "-", "DE-1900": "-", "DEd": "27", "DEd1900": "28", "DEm": "47", "DEm1900": "21", "DEs": "59", "DEs1900": "24", "DM": "CD-28 26", "Dmag": "13.8", "FK5": "5", "GLAT": "-81.13", "GLON": "26.30", "HD": "720", "HR": "34", "IRflag": "I", "Multiple": "W", "Name": "Kap2Scl", "RAh": "00", "RAh1900": "00", "RAm": "11", "RAm1900": "06", "RAs": "34.4", "RAs1900": "29.8", "RadVel": "-006", "SAO": "166103", "Sep": "46.0", "SpType": "K5III", "U-B": "+1.46", "Vmag": "5.41", "pmDE": "+0.016", "pmRA": "+0.010" },
 { "B-V": "+0.44", "DE-": "-", "DE-1900": "-", "DEd": "35", "DEd1900": "35", "DEm": "07", "DEm1900": "41", "DEs": "59", "DEs1900": "34", "DM": "CD-35 42", "FK5": "6", "GLAT": "-78.34", "GLON": "347.16", "HD": "739", "HR": "35", "Name": "The Scl", "Parallax": "+.034", "RAh": "00", "RAh1900": "00", "RAm": "11", "RAm1900": "06", "RAs": "44.0", "RAs1900": "39.0", "RadVel": "-002", "RotVel": "0", "SAO": "192388", "SpType": "F4V", "Vmag": "5.25", "pmDE": "+0.119", "pmRA": "+0.173" },
 { "B-V": "+1.45", "DE-": "+", "DE-1900": "+", "DEd": "48", "DEd1900": "47", "DEm": "09", "DEm1900": "35", "DEs": "09", "DEs1900": "45", "DM": "BD+47 21", "GLAT": "-14.20", "GLON": "116.16", "HD": "743", "HR": "36", "IRflag": "I", "RAh": "00", "RAh1900": "00", "RAm": "11", "RAm1900": "06", "RAs": "59.1", "RAs1900": "45.1", "RadVel": "+016", "SAO": "36148", "SpType": "gK4", "Vmag": "6.16", "pmDE": "+0.017", "pmRA": "+0.058" },
 { "B-V": "+1.48", "DE-": "-", "DE-1900": "-", "DEd": "17", "DEd1900": "18", "DEm": "56", "DEm1900": "29", "DEs": "18", "DEs1900": "38", "DM": "BD-18 14", "GLAT": "-77.10", "GLON": "76.32", "HD": "787", "HR": "37", "IRflag": "I", "Parallax": "-.015", "RAh": "00", "RAh1900": "00", "RAm": "12", "RAm1900": "07", "RAs": "10.0", "RAs1900": "04.0", "RadVel": "-008", "RotVel": "19", "SAO": "147144", "SpType": "K5III", "U-B": "+1.63", "Vmag": "5.25", "l_RotVel": "<", "n_RadVel": "V", "pmDE": "-0.031", "pmRA": "+0.056", "u_RotVel": ":" },
 { "B-V": "-0.13", "DE-": "+", "DE-1900": "+", "DEd": "37", "DEd1900": "37", "DEm": "41", "DEm1900": "08", "DEs": "36", "DEs1900": "15", "DM": "BD+36 12", "GLAT": "-24.55", "GLON": "114.55", "HD": "829", "HR": "38", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "12", "RAm1900": "07", "RAs": "50.4", "RAs1900": "38.2", "RadVel": "-010", "SAO": "53725", "SpType": "B2V", "U-B": "-0.70", "Vmag": "6.73", "pmDE": "-0.012", "pmRA": "+0.028" },
 { "B-V": "-0.23", "DE-": "+", "DE-1900": "+", "DEd": "15", "DEd1900": "14", "DEm": "11", "DEm1900": "37", "DEs": "01", "DEs1900": "40", "DM": "BD+14 14", "Dmag": "8.9", "FK5": "7", "GLAT": "-46.68", "GLON": "109.43", "HD": "886", "HR": "39", "IRflag": "I", "MultCnt": "3", "MultID": "AB", "Multiple": "W", "Name": "88Gam Peg", "NoteFlag": "*", "Parallax": "-.002", "R-I": "-0.19", "RAh": "00", "RAh1900": "00", "RAm": "13", "RAm1900": "08", "RAs": "14.2", "RAs1900": "05.1", "RadVel": "+004", "RotVel": "3", "SAO": "91781", "Sep": "163.4", "SpType": "B2IV", "U-B": "-0.87", "VarID": "Gam Peg", "Vmag": "2.83", "n_RadVel": "SBO", "pmDE": "-0.012", "pmRA": "+0.003", "r_IRflag": "'" },
 { "ADS": "161", "B-V": "+0.65", "DE-": "+", "DE-1900": "+", "DEd": "26", "DEd1900": "26", "DEm": "59", "DEm1900": "25", "DEs": "14", "DEs1900": "56", "DM": "BD+26 13", "Dmag": "1.1", "GLAT": "-35.12", "GLON": "112.56", "HD": "895", "HR": "40", "MultCnt": "3", "MultID": "AB", "NoteFlag": "*", "Parallax": "+.006", "RAh": "00", "RAh1900": "00", "RAm": "13", "RAm1900": "08", "RAs": "24.0", "RAs1900": "13.4", "RadVel": "-013", "SAO": "73823", "Sep": "0.1", "SpType": "G0III", "U-B": "+0.33", "Vmag": "6.30", "n_Parallax": "D", "pmDE": "-0.047", "pmRA": "-0.008" },
 { "B-V": "+0.31", "DE-": "+", "DE-1900": "+", "DEd": "41", "DEd1900": "40", "DEm": "02", "DEm1900": "29", "DEs": "07", "DEs1900": "00", "DM": "BD+40 29", "FK5": "2010", "GLAT": "-21.27", "GLON": "115.27", "HD": "905", "HR": "41", "Name": "23 And", "Parallax": "+.024", "RAh": "00", "RAh1900": "00", "RAm": "13", "RAm1900": "08", "RAs": "30.8", "RAs1900": "19.0", "RadVel": "-029", "RotVel": "25", "SAO": "36173", "SpType": "F0IV", "U-B": "-0.02", "Vmag": "5.72", "pmDE": "-0.148", "pmRA": "-0.123" },
 { "B-V": "+1.55", "DE-": "-", "DE-1900": "-", "DEd": "26", "DEd1900": "26", "DEm": "01", "DEm1900": "34", "DEs": "19", "DEs1900": "35", "DM": "CD-26 56", "GLAT": "-81.49", "GLON": "38.28", "HD": "942", "HR": "42", "IRflag": "I", "RAh": "00", "RAh1900": "00", "RAm": "13", "RAm1900": "08", "RAs": "42.1", "RAs1900": "37.8", "RadVel": "-030", "SAO": "166130", "SpType": "K5III", "VarID": "96", "Vmag": "5.94", "n_RadVel": "V", "pmDE": "-0.069", "pmRA": "+0.026" },
 { "B-V": "+1.48", "DE-": "-", "DE-1900": "-", "DEd": "26", "DEd1900": "26", "DEm": "17", "DEm1900": "50", "DEs": "05", "DEs1900": "29", "DM": "CD-26 57", "GLAT": "-81.54", "GLON": "36.52", "HD": "943", "HR": "43", "IRflag": "I", "RAh": "00", "RAh1900": "00", "RAm": "13", "RAm1900": "08", "RAs": "44.2", "RAs1900": "40.2", "RadVel": "+018", "SAO": "166131", "SpType": "K5III", "U-B": "+1.65", "Vmag": "6.31", "n_RadVel": "V", "pmDE": "+0.012", "pmRA": "-0.020" },
 { "B-V": "-0.01", "DE-": "+", "DE-1900": "+", "DEd": "33", "DEd1900": "32", "DEm": "12", "DEm1900": "39", "DEs": "22", "DEs1900": "01", "DM": "BD+32 21", "FK5": "2012", "GLAT": "-29.02", "GLON": "113.99", "HD": "952", "HR": "44", "RAh": "00", "RAh1900": "00", "RAm": "14", "RAm1900": "08", "RAs": "02.3", "RAs1900": "50.6", "RadVel": "+001", "RotVel": "56", "SAO": "53744", "SpType": "A1V", "U-B": "-0.05", "Vmag": "6.25", "pmDE": "-0.018", "pmRA": "-0.006" },
 { "B-V": "+1.57", "DE-": "+", "DE-1900": "+", "DEd": "20", "DEd1900": "19", "DEm": "12", "DEm1900": "39", "DEs": "24", "DEs1900": "02", "DM": "BD+19 27", "FK5": "1004", "GLAT": "-41.83", "GLON": "111.30", "HD": "1013", "HR": "45", "IRflag": "I", "Name": "89Chi Peg", "NoteFlag": "*", "Parallax": "+.015", "R-I": "+1.13", "RAh": "00", "RAh1900": "00", "RAm": "14", "RAm1900": "09", "RAs": "36.2", "RAs1900": "25.6", "RadVel": "-046", "SAO": "91792", "SpType": "M2+III", "U-B": "+1.93", "VarID": "99", "Vmag": "4.80", "n_RadVel": "V", "n_SpType": "e", "pmDE": "0.000", "pmRA": "+0.093" },
 { "ADS": "180", "B-V": "+1.62", "DE-": "-", "DE-1900": "-", "DEd": "07", "DEd1900": "08", "DEm": "46", "DEm1900": "20", "DEs": "50", "DEs1900": "13", "DM": "BD-08 26", "Dmag": "6.0", "GLAT": "-68.76", "GLON": "96.87", "HD": "1014", "HR": "46", "IRflag": "I", "NoteFlag": "*", "Parallax": "+.003", "R-I": "+1.03", "RAh": "00", "RAh1900": "00", "RAm": "14", "RAm1900": "09", "RAs": "27.6", "RAs1900": "20.8", "RadVel": "-002", "SAO": "128655", "Sep": "3.0", "SpType": "M3+III", "U-B": "+1.81", "VarID": "AD Cet", "Vmag": "5.12", "n_R-I": "E", "n_RadVel": "V?", "pmDE": "+0.004", "pmRA": "+0.059" },
 { "B-V": "+1.72", "DE-": "-", "DE-1900": "-", "DEd": "84", "DEd1900": "85", "DEm": "59", "DEm1900": "33", "DEs": "39", "DEs1900": "02", "DM": "CP-85 2", "FK5": "3972", "GLAT": "-32.06", "GLON": "303.91", "HD": "1032", "HR": "47", "RAh": "00", "RAh1900": "00", "RAm": "13", "RAm1900": "09", "RAs": "19.4", "RAs1900": "32.1", "RadVel": "+004", "SAO": "258217", "SpType": "M0-1III", "U-B": "+2.10", "Vmag": "5.77", "pmDE": "+0.008", "pmRA": "+0.004" },
 { "B-V": "+1.66", "DE-": "-", "DE-1900": "-", "DEd": "18", "DEd1900": "19", "DEm": "55", "DEm1900": "29", "DEs": "58", "DEs1900": "13", "DM": "BD-19 21", "GLAT": "-78.23", "GLON": "75.11", "HD": "1038", "HR": "48", "IRflag": "I", "Name": "7 Cet", "NoteFlag": "*", "Parallax": "+.029", "R-I": "+1.14", "RAh": "00", "RAh1900": "00", "RAm": "14", "RAm1900": "09", "RAs": "38.4", "RAs1900": "33.7", "RadVel": "-023", "SAO": "147169", "SpType": "M3III", "U-B": "+1.99", "VarID": "AE Cet", "Vmag": "4.44", "n_SpType": "e", "pmDE": "-0.067", "pmRA": "-0.024" },
 { "B-V": "-0.01", "DE-": "+", "DE-1900": "+", "DEd": "22", "DEd1900": "21", "DEm": "17", "DEm1900": "43", "DEs": "03", "DEs1900": "43", "DM": "BD+21 13", "GLAT": "-39.81", "GLON": "111.92", "HD": "1048", "HR": "49", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "14", "RAm1900": "09", "RAs": "56.1", "RAs1900": "45.3", "RadVel": "-015", "SAO": "73838", "SpType": "A1pSi", "U-B": "+0.12", "Vmag": "6.24", "pmDE": "-0.011", "pmRA": "+0.065" },
 { "ADS": "191", "B-V": "+0.31", "DE-": "+", "DE-1900": "+", "DEd": "08", "DEd1900": "08", "DEm": "49", "DEm1900": "15", "DEs": "15", "DEs1900": "56", "DM": "BD+08 19", "Dmag": "0.0", "GLAT": "-52.98", "GLON": "107.86", "HD": "1061", "HR": "50", "MultCnt": "3", "MultID": "A", "Name": "35 Psc", "NoteFlag": "*", "Parallax": "+.017", "RAh": "00", "RAh1900": "00", "RAm": "14", "RAm1900": "09", "RAs": "58.8", "RAs1900": "49.7", "RadVel": "+001", "RotVel": "86", "SAO": "109087", "Sep": "0.0", "SpType": "F0IV", "U-B": "+0.04", "VarID": "UU Psc", "Vmag": "5.79", "n_Parallax": "D", "n_RadVel": "SB2O", "pmDE": "-0.028", "pmRA": "+0.097" },
 { "B-V": "-0.08", "DE-": "-", "DE-1900": "-", "DEd": "09", "DEd1900": "10", "DEm": "34", "DEm1900": "07", "DEs": "11", "DEs1900": "31", "DM": "BD-10 30", "GLAT": "-70.44", "GLON": "95.06", "HD": "1064", "HR": "51", "RAh": "00", "RAh1900": "00", "RAm": "14", "RAm1900": "09", "RAs": "54.5", "RAs1900": "48.2", "RadVel": "+017", "SAO": "128660", "SpType": "B9V", "Vmag": "5.75", "n_RadVel": "V?", "pmDE": "-0.011", "pmRA": "+0.028" },
 { "DE-": "+", "DE-1900": "+", "DEd": "31", "DEd1900": "30", "DEm": "32", "DEm1900": "58", "DEs": "09", "DEs1900": "48", "DM": "BD+30 26", "GLAT": "-30.70", "GLON": "113.93", "HD": "1075", "HR": "52", "IRflag": "I", "RAh": "00", "RAh1900": "00", "RAm": "15", "RAm1900": "09", "RAs": "07.0", "RAs1900": "54.9", "RadVel": "+002", "SAO": "53755", "SpType": "K5", "Vmag": "6.45", "n_Vmag": "R", "pmDE": "-0.005", "pmRA": "+0.035" },
 { "B-V": "-0.02", "DE-": "+", "DE-1900": "+", "DEd": "27", "DEd1900": "26", "DEm": "16", "DEm1900": "43", "DEs": "59", "DEs1900": "40", "DM": "BD+26 23", "Dmag": "6.8", "GLAT": "-34.90", "GLON": "113.10", "HD": "1083", "HR": "53", "Multiple": "W", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "15", "RAm1900": "09", "RAs": "10.6", "RAs1900": "59.3", "RadVel": "-004", "RotVel": "230", "SAO": "73842", "Sep": "29.2", "SpType": "A1Vn", "U-B": "+0.02", "Vmag": "6.35", "n_RadVel": "SB", "pmDE": "-0.031", "pmRA": "+0.021" },
 { "B-V": "+1.34", "DE-": "-", "DE-1900": "-", "DEd": "34", "DEd1900": "35", "DEm": "54", "DEm1900": "27", "DEs": "16", "DEs1900": "36", "DM": "CD-35 65", "GLAT": "-78.99", "GLON": "345.80", "HD": "1089", "HR": "54", "RAh": "00", "RAh1900": "00", "RAm": "14", "RAm1900": "09", "RAs": "58.2", "RAs1900": "55.3", "RadVel": "-052", "SAO": "192418", "SpType": "K3III", "Vmag": "6.17", "pmDE": "-0.023", "pmRA": "+0.073" },
 { "ADS": "207", "B-V": "-0.07", "DE-": "+", "DE-1900": "+", "DEd": "76", "DEd1900": "76", "DEm": "57", "DEm1900": "23", "DEs": "03", "DEs1900": "42", "DM": "BD+76 5", "Dmag": "0.3", "GLAT": "14.22", "GLON": "120.89", "HD": "1141", "HR": "55", "NoteFlag": "*", "Parallax": "+.013", "RAh": "00", "RAh1900": "00", "RAm": "16", "RAm1900": "10", "RAs": "14.0", "RAs1900": "33.1", "RadVel": "-007", "SAO": "4071", "Sep": "0.8", "SpType": "B8Vnn", "U-B": "-0.26", "Vmag": "6.35", "n_Parallax": "D", "n_RadVel": "V", "pmDE": "-0.002", "pmRA": "+0.018" },
 { "ADS": "215", "B-V": "+0.05", "DE-": "+", "DE-1900": "+", "DEd": "43", "DEd1900": "43", "DEm": "35", "DEm1900": "02", "DEs": "41", "DEs1900": "24", "DM": "BD+42 41", "Dmag": "3.9", "GLAT": "-18.82", "GLON": "116.23", "HD": "1185", "HR": "56", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "16", "RAm1900": "11", "RAs": "21.6", "RAs1900": "06.2", "RadVel": "+002", "RotVel": "100", "SAO": "36221", "Sep": "9.2", "SpType": "A2VpSi", "U-B": "+0.03", "Vmag": "6.15", "pmDE": "-0.030", "pmRA": "+0.043" },
 { "B-V": "+1.35", "DE-": "-", "DE-1900": "-", "DEd": "31", "DEd1900": "32", "DEm": "26", "DEm1900": "00", "DEs": "47", "DEs1900": "06", "DM": "CD-32 72", "Dmag": "9.9", "FK5": "2014", "GLAT": "-81.18", "GLON": "1.53", "HD": "1187", "HR": "57", "IRflag": "I", "Multiple": "W", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "16", "RAm1900": "11", "RAs": "08.9", "RAs1900": "05.4", "RadVel": "+026", "SAO": "192430", "Sep": "64.0", "SpType": "K5III", "U-B": "+1.50", "Vmag": "5.67", "pmDE": "-0.030", "pmRA": "+0.122" },
 { "B-V": "+1.00", "DE-": "-", "DE-1900": "-", "DEd": "75", "DEd1900": "76", "DEm": "54", "DEm1900": "28", "DEs": "41", "DEs1900": "03", "DM": "CP-76 19", "GLAT": "-41.02", "GLON": "305.79", "HD": "1221", "HR": "58", "RAh": "00", "RAh1900": "00", "RAm": "15", "RAm1900": "11", "RAs": "55.2", "RAs1900": "20.4", "RadVel": "+016", "SAO": "255650", "SpType": "G8-K0III", "U-B": "+0.72", "Vmag": "6.49", "pmDE": "+0.006", "pmRA": "-0.013" },
 { "B-V": "+0.92", "DE-": "+", "DE-1900": "+", "DEd": "08", "DEd1900": "07", "DEm": "14", "DEm1900": "41", "DEs": "24", "DEs1900": "05", "DM": "BD+07 27", "FK5": "2015", "GLAT": "-53.64", "GLON": "108.28", "HD": "1227", "HR": "59", "Name": "36 Psc", "RAh": "00", "RAh1900": "00", "RAm": "16", "RAm1900": "11", "RAs": "34.1", "RAs1900": "25.7", "RadVel": "+001", "SAO": "109100", "SpType": "G8II-III", "U-B": "+0.66", "Vmag": "6.11", "pmDE": "-0.019", "pmRA": "-0.020" },
 { "ADS": "222", "B-V": "+0.88", "DE-": "+", "DE-1900": "+", "DEd": "61", "DEd1900": "60", "DEm": "32", "DEm1900": "58", "DEs": "00", "DEs1900": "39", "DM": "BD+60 21", "Dmag": "6.4", "GLAT": "-01.06", "GLON": "118.83", "HD": "1239", "HR": "60", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "16", "RAm1900": "11", "RAs": "57.1", "RAs1900": "34.6", "RadVel": "-004", "SAO": "11084", "Sep": "19.4", "SpType": "G8III", "U-B": "+0.59", "Vmag": "5.74", "pmDE": "-0.001", "pmRA": "-0.001" },
 { "B-V": "-0.09", "DE-": "-", "DE-1900": "-", "DEd": "20", "DEd1900": "20", "DEm": "12", "DEm1900": "45", "DEs": "38", "DEs1900": "57", "DM": "BD-21 24", "GLAT": "-79.47", "GLON": "72.13", "HD": "1256", "HR": "61", "NoteFlag": "*", "RAh": "00", "RAh1900": "00", "RAm": "16", "RAm1900": "11", "RAs": "42.5", "RAs1900": "38.1", "RadVel": "+019", "SAO": "166167", "SpType": "B8III", "U-B": "-0.48", "VarID": "113", "Vmag": "6.47", "n_RadVel": "V", "pmDE": "-0.014", "pmRA": "+0.012" },
 { "B-V": "-0.09", "DE-": "+", "DE-1900": "+", "DEd": "47", "DEd1900": "47", "DEm": "56", "DEm1900": "23", "DEs": "51", "DEs1900": "31", "DM": "BD+47 50", "FK5": "2016", "GLAT": "-14.53", "GLON": "117.01", "HD": "1279", "HR": "62", "RAh": "00", "RAh1900": "00", "RAm": "17", "RAm1900": "11", "RAs": "09.1", "RAs1900": "52.3", "RadVel": "-009", "RotVel": "0", "SAO": "36236", "SpType": "B7III", "U-B": "-0.44", "Vmag": "5.89", "n_RadVel": "V?", "pmDE": "0.000", "pmRA": "+0.008" },
 { "B-V": "+0.06", "DE-": "+", "DE-1900": "+", "DEd": "38", "DEd1900": "38", "DEm": "40", "DEm1900": "07", "DEs": "54", "DEs1900": "35", "DM": "BD+37 34", "GLAT": "-23.70", "GLON": "115.62", "HD": "1280", "HR": "63", "Name": "24The And", "NoteFlag": "*", "Parallax": "+.022", "R-I": "+0.01", "RAh": "00", "RAh1900": "00", "RAm": "17", "RAm1900": "11", "RAs": "05.5", "RAs1900": "51.9", "RadVel": "+001", "RotVel": "107", "SAO": "53777", "SpType": "A2V", "U-B": "+0.04", "VarID": "116", "Vmag": "4.61", "n_RadVel": "V", "pmDE": "-0.019", "pmRA": "-0.050" },
 */

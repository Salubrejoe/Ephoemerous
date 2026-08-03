
import SwiftUI


struct EStar: Identifiable, Hashable {
    /// The catalogue designation IS the identity — "α Ori" is Betelgeuse
    /// wherever it was built from.
    ///
    /// This used to be a fresh `UUID()` per instance, which quietly broke
    /// every cross-array comparison. `favouriteStars` and the named-star
    /// list are built from separate passes, so one star carried DIFFERENT
    /// ids in each: MainView's "don't label a favourite twice" filter never
    /// matched, and every favourited named star drew TWICE — once gold with
    /// its heart, once plain white. `ESkyObject.id` (`star_<id>`) inherited
    /// the instability, so the per-frame position dictionaries and the
    /// detail sheet's identity were unreliable too.
    ///
    /// Depends on designations being unique, which `StarDatabase` now
    /// guarantees by folding double-star companion records together.
    var id: String { name }

    let name           : String
    let rightAscension : Angle
    let declination    : Angle
    let magnitude      : Double
    let spectralClass  : EHRClass
    let pmRA           : Double
    let pmDE           : Double

    /// Unit vector in the (un-precessed, un-rotated) equatorial frame,
    /// computed once from RA/Dec at load. Constant for the star's life —
    /// RA/Dec never change — so the per-frame star cull can dot against
    /// this with zero trig (see `StarsLayer` / `EGraphicContext.starCull`).
    /// Precession nudges a star by arcminutes, far under the cull's
    /// screen margin, so the un-precessed vector is exact enough for the
    /// visibility test; survivors still get the full precise projection.
    let equatorialVector: SIMD3<Double>
    
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
        let ra  = EStar.calculateRA(from: starData)
        let dec = EStar.calculateDec(from: starData)
        self.name           = EStar.calculateName(from: starData)
        self.rightAscension = ra
        self.declination    = dec
        self.magnitude      = EStar.calculateMagnitude(from: starData)
        self.spectralClass  = EStar.calculateSpectralClass(from: starData)
        self.pmRA           = EStar.calculateProperMotionRA(from: starData)
        self.pmDE           = EStar.calculateProperMotionDec(from: starData)
        self.equatorialVector = EPrecession.equatorialVector(ra: ra, dec: dec)
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
        guard let input = starData.name else { return "Unknown" }
        let last3 = String(input.suffix(3))
        guard let constellation = EConstellation(rawValue: last3) else { return "Unknown" }
        var prefix = String(input.dropLast(3)).trimmingCharacters(in: .whitespaces)
        // Detect Flamsteed number: digits before a space when no Greek abbrev present
        var flamsteed = ""
        let hasGreek = greekLetterMap.keys.contains(where: { prefix.contains($0) })
        if !hasGreek, let spaceIdx = prefix.firstIndex(of: " ") {
            let maybeNum = String(prefix[prefix.startIndex..<spaceIdx])
            if maybeNum.allSatisfy({ $0.isNumber }) {
                flamsteed = maybeNum
                prefix = String(prefix[prefix.index(after: spaceIdx)...])
            }
        }
        // Strip disambiguation digits, then map Greek abbreviations to symbols
        prefix = prefix.filter { !$0.isNumber }
        for (spelling, symbol) in greekLetterMap {
            prefix = prefix.replacingOccurrences(of: spelling, with: symbol)
        }
        prefix = prefix.trimmingCharacters(in: .whitespaces)
        var parts: [String] = []
        if !flamsteed.isEmpty { parts.append(flamsteed) }
        if !prefix.isEmpty    { parts.append(prefix)    }
        parts.append(constellation.rawValue)
        return parts.joined(separator: " ")
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


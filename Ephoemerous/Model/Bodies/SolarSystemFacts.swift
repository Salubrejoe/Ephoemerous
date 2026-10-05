import Foundation

// MARK: - Solar-system facts
// The fixed numbers behind the Sun, Moon and planet sheets' tiles — size,
// orbit, the near and far ends of their distance from us — as numbers the
// tiles can draw with, not pre-written strings.
struct BodyFacts {
    /// Mean diameter, km.
    let diameterKm:    Double
    /// Distance from Earth, km: the nearest and farthest it ever gets.
    let nearestKm:     Double
    let farthestKm:    Double
    /// Orbital period around the Sun (planets) or the Earth (the Moon), days.
    let periodDays:    Double?
    /// Mean distance from the Sun, AU (planets).
    let semiMajorAU:   Double?

    static let earthDiameterKm = 12_742.0
    static let kmPerAU         = 149_597_870.7

    static let sun  = BodyFacts(diameterKm: 1_391_400,
                               nearestKm:  147_098_000, farthestKm: 152_098_000,
                               periodDays: nil, semiMajorAU: nil)
    static let moon = BodyFacts(diameterKm: 3_474.8,
                                nearestKm:  356_400, farthestKm: 406_700,
                                periodDays: 27.32, semiMajorAU: nil)

    /// A planet's facts. Nearest / farthest from Earth across the ellipses
    /// — each orbit's own perihelion q = a(1 − e) and aphelion Q = a(1 + e),
    /// and the Earth's (0.983–1.017 AU). Circular orbits put Saturn's
    /// "nearest" FARTHER than where it actually sits some years.
    static func planet(_ p: Planet) -> BodyFacts? {
        guard let (d, a, e, period) = table[p.name] else { return nil }
        let q = a * (1 - e), Q = a * (1 + e)
        let earthQ = 1.0167, earthq = 0.9833
        let nearest = a > 1 ? q - earthQ : earthq - Q      // outer : inner
        return BodyFacts(diameterKm:  d,
                         nearestKm:   max(0.01, nearest) * kmPerAU,
                         farthestKm:  (Q + earthQ) * kmPerAU,
                         periodDays:  period,
                         semiMajorAU: a)
    }

    /// Diameter km, semi-major axis AU, eccentricity, sidereal period days.
    private static let table: [String: (Double, Double, Double, Double)] = [
        Strings.Planets.mercury: (4_879,   0.387, 0.2056,     88.0),
        Strings.Planets.venus:   (12_104,  0.723, 0.0068,    224.7),
        Strings.Planets.mars:    (6_779,   1.524, 0.0934,    687.0),
        Strings.Planets.jupiter: (139_820, 5.203, 0.0489,  4_332.6),
        Strings.Planets.saturn:  (116_460, 9.537, 0.0565, 10_759.2),
        Strings.Planets.uranus:  (50_724, 19.19,  0.0457, 30_688.5),
        Strings.Planets.neptune: (49_244, 30.07,  0.0113, 60_182.0),
    ]

    /// "11 Earths across", "a quarter of Earth" — the size in a phrase.
    var sizePhrase: String {
        let r = diameterKm / Self.earthDiameterKm
        if r >= 1.5 { return String(localized: "\(Int(r.rounded())) Earths across") }
        if r >= 0.9 { return String(localized: "About Earth's size") }
        if r >= 0.4 { return String(localized: "About half of Earth") }
        return String(localized: "About a quarter of Earth")
    }

    /// "Goes round the Sun every 11.9 years" — or days, for the quick ones.
    var periodPhrase: String? {
        guard let days = periodDays else { return nil }
        if days < 400 { return String(localized: "\(Int(days.rounded())) days") }
        return String(localized: "\((days / 365.25).formatted(.number.precision(.fractionLength(1)))) years")
    }
}

// MARK: - Moon phases ahead
extension MoonPosition {

    /// The next full and new Moon after `date` — found by stepping the lit
    /// fraction through the coming month and refining the turning points.
    static func nextFullAndNew(after date: Date) -> (full: Date?, new: Date?) {
        let step: TimeInterval = 3 * 3_600
        var full: Date?, new: Date?
        var t = date
        var a = illuminatedFraction(for: t)
        var b = illuminatedFraction(for: t.addingTimeInterval(step))
        for _ in 0 ..< 248 {                                    // ~31 days
            let c = illuminatedFraction(for: t.addingTimeInterval(2 * step))
            if full == nil, b >= a, b >= c, b > 0.9 { full = t.addingTimeInterval(step) }
            if new  == nil, b <= a, b <= c, b < 0.1 { new  = t.addingTimeInterval(step) }
            if full != nil, new != nil { break }
            t = t.addingTimeInterval(step); a = b; b = c
        }
        return (full, new)
    }
}

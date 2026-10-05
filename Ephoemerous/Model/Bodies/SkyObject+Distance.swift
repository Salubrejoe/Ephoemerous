import Foundation

// MARK: - SkyObject + Distance
// How far away an object is, as a short label — LOOK mode's crosshair
// writes it round the bottom of its ring. Each kind in its natural unit:
// stars in light-years, the planets and the Sun in astronomical units, the
// Moon in kilometres. `nil` where we hold no honest number (most catalogue
// stars, spacecraft, constellations) — the ring simply stays closed there.
extension SkyObject {

    func distanceLabel(at date: Date) -> String? {
        switch self {
        case .star(let s):
            guard let ly = s.distanceLY, ly > 0 else { return nil }
            return ly >= 100 ? String(localized: "\(Int(ly.rounded())) ly")
                             : String(localized: "\(ly, format: .number.precision(.fractionLength(1))) ly")
        case .sun:
            return Self.au(PlanetPosition.sunDistanceAU(date: date))
        case .planet(let p):
            guard let d = PlanetPosition.distanceAU(p, date: date) else { return nil }
            return Self.au(d)
        case .moon:
            // To the nearest thousand km — the Moon swings ±20 000 km a
            // month, so finer digits would only flicker past.
            let km = (MoonPosition.distanceKm(for: date) / 1000).rounded() * 1000
            return String(localized: "\(Int(km), format: .number) km")
        case .constellation, .spacecraft:
            return nil
        }
    }

    /// Two decimals inside 10 AU (the inner planets move visibly), one
    /// beyond (Neptune's 29.4 needs no more).
    private static func au(_ d: Double) -> String {
        String(localized: "\(d, format: .number.precision(.fractionLength(d < 10 ? 2 : 1))) AU")
    }
}

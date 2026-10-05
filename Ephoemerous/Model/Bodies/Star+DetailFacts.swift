import Foundation

// MARK: - Star + detail facts
// The numbers behind the star sheet's tiles, worked out once here so the
// tiles only draw. Each answers a question the tile asks in words.
extension Star {

    // MARK: Designation

    /// The name astronomers use, for the hero's subtitle: Bayer's Greek
    /// letter and the constellation's Latin genitive — "α Persei". A star
    /// without a letter keeps its catalogue name; one whose catalogue name
    /// IS its title says only where it lives.
    var designation: String {
        if let letter = bayerLetter { return "\(letter) \(constellation.genitive)" }
        return properName != nil ? name : constellation.localizedName
    }

    // MARK: Distance

    /// Stars to set this one against on the distance line: its own
    /// constellation's figure-mates with a known distance — the line's
    /// story is that a constellation is NOT flat. Too few of them (under
    /// three besides this star) and it borrows famous anchors instead.
    var distanceCompanions: (stars: [Star], isConstellation: Bool) {
        let mates = Self.distanceCatalogue.filter { $0.constellation == constellation && $0.id != id }
        if mates.count >= 3 { return (mates, true) }
        let anchors = Self.distanceAnchorNames.compactMap { name in
            Self.distanceCatalogue.first { $0.displayName == name && $0.id != id }
        }
        return (anchors, false)
    }

    /// The nearest and farthest of a set of stars, by known distance.
    static func span(of stars: [Star]) -> ClosedRange<Double>? {
        let d = stars.compactMap(\.distanceLY)
        guard let lo = d.min(), let hi = d.max() else { return nil }
        return lo...hi
    }

    /// The year the light you see left the star, as a phrase: "1516", or
    /// "around 500 BC" for the far ones. `nil` without a distance.
    func lightDepartureYear(seenIn year: Int) -> String? {
        guard let ly = distanceLY, ly > 0 else { return nil }
        let left = year - Int(ly.rounded())
        return left > 0 ? "\(left)" : String(localized: "\(1 - left) BC")
    }

    /// Every star with a known distance — the distance line's population.
    private static let distanceCatalogue: [Star] =
        StarDatabase.shared.workableStars.filter { $0.distanceLY != nil }

    /// Household names spread across the depths, for a constellation with
    /// too few measured stars to make its own line.
    private static let distanceAnchorNames = ["Sirius", "Vega", "Polaris", "Deneb"]

    // MARK: Brightness

    /// How the eye meets this magnitude, in plain words.
    var brightnessPhrase: String {
        switch magnitude {
        case ..<1.0:  String(localized: "One of the brightest in the sky")
        case ..<2.5:  String(localized: "Easy to see, even from a city")
        case ..<4.0:  String(localized: "Clear from the suburbs")
        case ..<5.5:  String(localized: "Needs a dark sky")
        default:      String(localized: "At the edge of naked-eye sight")
        }
    }

    // MARK: Proper motion
    // The catalogue (BSC5) gives proper motion in ARCSECONDS a year; the
    // sheet used to print those numbers as milliarcseconds, so every star
    // read "+0.0, −0.0 mas/yr". Converted here, once.

    /// Proper motion in RA (μα·cos δ) and Dec, milliarcseconds a year.
    var properMotionMas: (ra: Double, dec: Double) { (pmRA * 1000, pmDE * 1000) }

    /// Total drift across the sky, milliarcseconds a year.
    var properMotionTotalMas: Double {
        let (a, d) = properMotionMas
        return (a * a + d * d).squareRoot()
    }

    /// Which way the star drifts across the sky, as a compass word —
    /// "south-west". `nil` when the catalogue records no motion.
    var driftHeading: String? {
        let (ra, dec) = properMotionMas
        guard (ra * ra + dec * dec) > 0.25 else { return nil }
        // Position angle: from north, through EAST (+RA).
        let angle = atan2(ra, dec) * 180 / .pi
        let index = Int(((angle < 0 ? angle + 360 : angle) / 45).rounded()) % 8
        return [String(localized: "north"),      String(localized: "north-east"),
                String(localized: "east"),       String(localized: "south-east"),
                String(localized: "south"),      String(localized: "south-west"),
                String(localized: "west"),       String(localized: "north-west")][index]
    }

    /// Years to drift one full-Moon width (~31′ = 1 860″). `nil` when the
    /// catalogue records no motion.
    var yearsToCrossMoonWidth: Double? {
        let arcsecPerYear = properMotionTotalMas / 1000
        guard arcsecPerYear > 0.0005 else { return nil }
        return 1_860 / arcsecPerYear
    }
}

// MARK: - Day path
// The star's height over a day, for the rise/set tile — Weather's sunset
// curve, for any star.
struct StarDayPath {

    /// (time, altitude in radians) every `step`, across `window` centred
    /// on `date`.
    let samples: [(date: Date, altitude: Double)]
    let now:     Date

    static let window: TimeInterval = 24 * 3_600
    static let step:   TimeInterval = 10 * 60

    init(object: SkyObject, around date: Date, observer: SatelliteSky.Observer) {
        now = date
        let start = date.addingTimeInterval(-Self.window / 2)
        samples = stride(from: 0, through: Self.window, by: Self.step).compactMap { t in
            let when = start.addingTimeInterval(t)
            return object.altitude(at: when, from: observer).map { (when, $0) }
        }
    }

    /// The highest point of the window — when and how high.
    var culmination: (date: Date, altitude: Double)? {
        samples.max { $0.altitude < $1.altitude }
    }

    /// Never dips under the horizon / never climbs over it, all day.
    var alwaysUp:   Bool { samples.allSatisfy { $0.altitude > 0 } }
    var alwaysDown: Bool { samples.allSatisfy { $0.altitude <= 0 } }
}

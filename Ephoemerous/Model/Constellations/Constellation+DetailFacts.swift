import Foundation
import simd

// MARK: - Constellation + detail facts
// The numbers behind the constellation card's tiles.
extension Constellation {

    // MARK: Stars

    /// Every catalogue star filed under this constellation, brightest first.
    var catalogueStars: [Star] {
        StarDatabase.shared.workableStars
            .filter { $0.constellation == self && $0.name != "Unknown" }
            .sorted { $0.magnitude < $1.magnitude }
    }

    /// The stars its figure draws through, brightest first.
    var figureStars: [Star] {
        let segs = ConstellationLines.shared.segments[self] ?? []
        var seen = Set<String>()
        return segs.flatMap { [$0.a, $0.b] }
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.magnitude < $1.magnitude }
    }

    /// Its stars with a measured distance — the depth tile's population.
    var measuredStars: [Star] { catalogueStars.filter { $0.distanceLY != nil } }

    // MARK: Season

    /// The figure's height at 21:00 local, mid-month, through `year` — one
    /// value per month, radians. "When can I see it" is an evening question.
    func eveningAltitudes(year: Int, from observer: SatelliteSky.Observer) -> [Double] {
        let cal = Calendar.current
        return (1 ... 12).map { month in
            guard let date = cal.date(from: DateComponents(year: year, month: month, day: 15, hour: 21)),
                  let alt  = SkyObject.constellation(self).altitude(at: date, from: observer)
            else { return -.pi / 2 }
            return alt
        }
    }
}

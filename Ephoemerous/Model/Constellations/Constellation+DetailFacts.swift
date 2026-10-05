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

    // MARK: Size
    // The IAU's official areas (square degrees, Delporte boundaries) — the
    // one honest measure of a constellation's size; an estimate from the
    // figure's outline would be wrong for every sprawling one.

    /// Area of sky, square degrees.
    var areaSquareDegrees: Double? { Self.iauAreas[rawValue] }

    /// 1 = largest (Hydra) … 88 = smallest (Crux).
    var sizeRank: Int? {
        guard let area = areaSquareDegrees else { return nil }
        return Self.iauAreas.values.filter { $0 > area }.count + 1
    }

    /// The whole sky, square degrees.
    static let wholeSkySquareDegrees = 41_252.96

    private static let iauAreas: [String: Double] = [
        "Hya": 1302.844, "Vir": 1294.428, "UMa": 1279.660, "Cet": 1231.411, "Her": 1225.148,
        "Eri": 1137.919, "Peg": 1120.794, "Dra": 1082.952, "Cen": 1060.422, "Aqr":  979.854,
        "Oph":  948.340, "Leo":  946.964, "Boo":  906.831, "Psc":  889.417, "Sgr":  867.432,
        "Cyg":  803.983, "Tau":  797.249, "Cam":  756.828, "And":  722.278, "Pup":  673.434,
        "Aur":  657.438, "Aql":  652.473, "Ser":  636.928, "Per":  614.997, "Cas":  598.407,
        "Ori":  594.120, "Cep":  587.787, "Lyn":  545.386, "Lib":  538.052, "Gem":  513.761,
        "Cnc":  505.872, "Vel":  499.649, "Sco":  496.783, "Car":  494.184, "Mon":  481.569,
        "Scl":  474.764, "Phe":  469.319, "CVn":  465.194, "Ari":  441.395, "Cap":  413.947,
        "For":  397.502, "Com":  386.475, "CMa":  380.118, "Pav":  377.666, "Gru":  365.513,
        "Lup":  333.683, "Sex":  313.515, "Tuc":  294.557, "Ind":  294.006, "Oct":  291.045,
        "Lep":  290.291, "Lyr":  286.476, "Crt":  282.398, "Col":  270.184, "Vul":  268.165,
        "UMi":  255.864, "Tel":  251.512, "Hor":  248.885, "Pic":  246.739, "PsA":  245.375,
        "Hyi":  243.035, "Ant":  238.901, "Ara":  237.057, "LMi":  231.956, "Pyx":  220.833,
        "Mic":  209.513, "Aps":  206.327, "Lac":  200.688, "Del":  188.549, "Crv":  183.801,
        "CMi":  183.367, "Dor":  179.173, "CrB":  178.710, "Nor":  165.290, "Men":  153.484,
        "Vol":  141.354, "Mus":  138.355, "Tri":  131.847, "Cha":  131.592, "CrA":  127.696,
        "Cae":  124.865, "Ret":  113.936, "TrA":  109.978, "Sct":  109.114, "Cir":   93.353,
        "Sge":   79.932, "Equ":   71.641, "Cru":   68.447,
    ]

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

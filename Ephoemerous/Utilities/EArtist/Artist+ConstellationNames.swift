import SwiftUI

// MARK: - Constellation visibility
// The live half of the old Artist+ConstellationNames: "does this
// constellation rise / set at the observer's latitude", which drives
// `constellationKind` (used by the detail sheet + the SkyLab to colour
// favourite figures). The plain-text label drawing — placeholders, fonts,
// `drawConstellationLabel` — moved to DeprecationStation with the old
// ConstellationNamesLayer.
extension Artist {

    /// Margin (degrees of declination) for the horizon visibility test.
    /// Constellations span tens of degrees, so a centroid just below 90°
    /// from the observer can still have figure-stars rising.
    var constellationVisibilityMargin: Double { 25 }

    /// `true` when any part of a constellation near `decDegrees` rises above
    /// the horizon for an observer at `observerLatitude`.
    func constellationEverVisible(decDegrees: Double, observerLatitude: Double) -> Bool {
        abs(observerLatitude - decDegrees) < 90 + constellationVisibilityMargin
    }

    /// `true` when the constellation's centroid never sets at the observer's
    /// latitude (within |φ| of their celestial pole, same hemisphere).
    func constellationCircumpolar(decDegrees: Double, observerLatitude: Double) -> Bool {
        if observerLatitude >= 0 {
            return decDegrees >= 90 - observerLatitude
        } else {
            return decDegrees <= -(90 + observerLatitude)
        }
    }
    // (constellationKind moved to DeprecationStation with the myth taxonomy;
    //  live constellations wear one neutral tint now.)
}

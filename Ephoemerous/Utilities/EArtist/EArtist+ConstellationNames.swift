import SwiftUI

// MARK: - Constellation names
// Visibility classification + display-string helpers for the
// constellation POI labels (`ConstellationNamesLayer`).
//
// The badge palette + tier come from `POIConstellationKind`; this
// file owns the *geometry* of "does this constellation rise / set
// at the observer's latitude" and the lookup that turns those tests
// into a kind. The bespoke text-only label that used to live here
// (Stellarium-style ALL CAPS serif italic) is gone — Apple-Maps
// pills handle text in `drawPOILabel(…)`.
extension EArtist {

    /// Renderered-scale threshold below which constellation badges
    /// are not tappable. Visual badges still render past this; the
    /// hit-test layer just suppresses targets so an accidental tap
    /// can't ambush a pinch-to-zoom.
    var labelTapMinScale: Double { 130 }

    /// Margin (degrees of declination) for the horizon visibility
    /// test. Constellations span tens of degrees, so a centroid
    /// just below 90° from the observer can still have figure-stars
    /// rising — the margin keeps those visible.
    var constellationVisibilityMargin: Double { 25 }

    /// `true` when any part of a constellation near `decDegrees` rises
    /// above the horizon for an observer at `observerLatitude`. A point
    /// at declination δ culminates at altitude 90° − |φ − δ|, so it is
    /// below the horizon for the whole sidereal day once |φ − δ| ≥ 90°.
    func constellationEverVisible(decDegrees: Double, observerLatitude: Double) -> Bool {
        abs(observerLatitude - decDegrees) < 90 + constellationVisibilityMargin
    }

    /// `true` when the constellation's centroid never sets at the
    /// observer's latitude — i.e. the centroid sits within |φ| of
    /// the observer's celestial pole. Same hemisphere as observer
    /// (north + north, south + south); a southern observer's
    /// circumpolar constellations live at negative dec.
    func constellationCircumpolar(decDegrees: Double, observerLatitude: Double) -> Bool {
        if observerLatitude >= 0 {
            return decDegrees >= 90 - observerLatitude
        } else {
            return decDegrees <= -(90 + observerLatitude)
        }
    }

    /// Resolve a constellation's POI tier from its centroid
    /// declination + the observer's latitude. Zodiac wins over
    /// visibility (an ecliptic constellation is always "zodiac",
    /// even if it never rises for a polar observer).
    func constellationKind(_ cons: EConstellation,
                           decDegrees: Double,
                           observerLatitude: Double) -> POIConstellationKind {
        if cons.isZodiac { return .zodiac }
        if !constellationEverVisible(decDegrees:       decDegrees,
                                     observerLatitude: observerLatitude) {
            return .foreverInvisible
        }
        if constellationCircumpolar(decDegrees:       decDegrees,
                                    observerLatitude: observerLatitude) {
            return .circumpolar
        }
        return .standard
    }

    /// Title-cased constellation name as it appears on the POI
    /// label (e.g. "Cassiopeia"). The previous Stellarium-style
    /// ALL CAPS render is gone now that labels share Apple-Maps's
    /// mixed-case voice.
    func constellationLabelText(for cons: EConstellation) -> String {
        cons.fullName
    }
}

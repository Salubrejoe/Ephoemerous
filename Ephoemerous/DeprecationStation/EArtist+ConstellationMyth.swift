import SwiftUI

// MARK: - Constellation myth palette (DEPRECATED)
//
// The myth-colour resolvers, retired from the live app (constellations now
// wear one neutral tint — see `EArtist.constellationGradient`). Kept here,
// self-contained, for the deprecated canvas layers + `EMythDetailView`.
//
// Cycles correspond to the `myths` axis in `constellation_categories.json`;
// the FIRST entry of a constellation's `myths` array is its primary cycle.
extension EArtist {

    func constellationMythGradient(_ myth: POIConstellationMyth)
        -> (top: Color, bottom: Color)
    {
        palette.myth(myth)
    }

    /// Resolve a constellation's POI kind: `.foreverInvisible` when the
    /// centroid never rises here, else `.myth(_)`. (Moved from the live
    /// EArtist+ConstellationNames with the myth taxonomy.)
    func constellationKind(_ cons: EConstellation,
                           decDegrees: Double,
                           observerLatitude: Double) -> POIConstellationKind {
        if !constellationEverVisible(decDegrees:       decDegrees,
                                     observerLatitude: observerLatitude) {
            return .foreverInvisible
        }
        return .myth(constellationMyth(of: cons))
    }

    /// Resolve the (top, bottom) badge gradient for a constellation kind.
    /// `foreverInvisible` overrides with a recessive gray; everything else
    /// dispatches to the myth palette. (Moved from the live POIStyle and
    /// renamed off `constellationGradient` — that name is now the live
    /// neutral tint.)
    func deprecatedConstellationGradient(kind: POIConstellationKind) -> (top: Color, bottom: Color) {
        switch kind {
        case .foreverInvisible:
            return constellationForeverInvisibleGradient
        case .myth(let myth):
            return constellationMythGradient(myth)
        }
    }

    /// Visual override applied when a constellation's centroid
    /// never rises at the observer's latitude. Wins over the
    /// myth colour — a recessive grey that lets the eye skip
    /// past constellations you can't see anyway.
    var constellationForeverInvisibleGradient: (top: Color, bottom: Color) {
        palette.mythForeverInvisible
    }

    /// Resolve a constellation's primary mythological cycle by
    /// reading its `myths.first` from the JSON-loaded categories.
    /// Falls back to `.none` when the constellation has no myth
    /// listed or the string doesn't match a known case.
    func constellationMyth(of cons: EConstellation) -> POIConstellationMyth {
        guard
            let myth  = ConstellationCategories.shared.category(for: cons)?.myths.first,
            let value = POIConstellationMyth(rawValue: myth)
        else { return .none }
        return value
    }
}

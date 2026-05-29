import SwiftUI

// MARK: - Constellation myth palette
//
// Every constellation badge picks its top → bottom gradient from
// `palette.myth(_:)` — see `EPalette.swift` for the per-cycle
// values. The extension here just wraps the lookup so existing
// callers (`constellationMythGradient(_:)`,
// `constellationForeverInvisibleGradient`) keep their shape.
//
// Cycles correspond to the `myths` axis in
// `constellation_categories.json`; the FIRST entry of a
// constellation's `myths` array is its primary cycle.
// Constellations with no myth (Lacaille / Bayer / Hevelius
// additions, mostly) fall through to `.none`.
extension EArtist {

    func constellationMythGradient(_ myth: POIConstellationMyth)
        -> (top: Color, bottom: Color)
    {
        palette.myth(myth)
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

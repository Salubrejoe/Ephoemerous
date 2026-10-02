import SwiftUI

// MARK: - Constellation entity symbol  ▼ TWEAK HERE ▼
//
// Each constellation's badge SYMBOL is picked from the JSON
// `types` axis — what the constellation depicts (hero, animal,
// instrument, …). The colour gradient is independent: it's
// driven by `myths` (see Artist+ConstellationMyth.swift). So
// the badge silhouette answers "what is this?" while the colour
// answers "which story?".
//
// To retune one entity's glyph, change its SF Symbol name below
// and recompile.
extension Artist {

    func constellationEntitySymbol(_ entity: POIConstellationEntity) -> Symbol {
        switch entity {
        case .hero:       return .entityHero
        case .animal:     return .entityAnimal
        case .creature:   return .entityCreature
        case .object:     return .entityObject
        case .instrument: return .entityInstrument
        case .deity:      return .entityDeity
        case .none:       return .entityFallback
        }
    }

    /// The constellation's own stick figure as a custom SF Symbol —
    /// `Assets.xcassets/Constellations/constellation.<iau>.symbolset`,
    /// generated from `constellationLines.json`. Takes `.font` weight and
    /// scale like any SF Symbol; lines sit on the hierarchical secondary
    /// layer, stars on primary. `.none` has no figure, so it keeps the
    /// generic glyph.
    func constellationFigure(_ cons: Constellation) -> Image {
        guard cons != .none else { return Image(symbol: .entityFallback) }
        return Image("constellation.\(cons.rawValue.lowercased())")
    }

    /// Resolve a constellation's primary entity by reading its
    /// `types.first` from the JSON-loaded categories. Falls back
    /// to `.none` when the constellation has no `types` entry or
    /// the string doesn't match a known case.
    func constellationEntity(of cons: Constellation) -> POIConstellationEntity {
        guard
            let type  = ConstellationCategories.shared.category(for: cons)?.types.first,
            let value = POIConstellationEntity(rawValue: type)
        else { return .none }
        return value
    }
}

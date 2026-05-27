import SwiftUI

// MARK: - Constellation entity palette  ▼ TWEAK HERE ▼
//
// Every constellation badge picks its top → bottom gradient from
// this single switch. To retune one cycle, edit its two `Color(
// red:green:blue:)` lines and recompile — every constellation
// belonging to that myth follows.
//
// Cycles correspond to the `myths` axis in
// `constellation_categories.json`; the FIRST entry of a
// constellation's `myths` array is its primary entity. Constella-
// tions with no myth (Lacaille / Bayer / Hevelius additions, mostly)
// fall through to `.none`.
extension EArtist {

    func constellationEntityGradient(_ entity: POIConstellationEntity)
        -> (top: Color, bottom: Color)
    {
        switch entity {

        case .perseus:
            // Heroic red — Andromeda, Cassiopeia, Cepheus, Cetus,
            // Pegasus, Perseus.
            return (Color(red: 0.95, green: 0.45, blue: 0.45),
                    Color(red: 0.55, green: 0.10, blue: 0.15))

        case .hercules:
            // Warm strength orange — Hercules, Ara, Corona Borealis,
            // Crater, Corvus, Draco, Hydra, Leo, Lyra, Ophiuchus,
            // Sagitta, Serpens.
            return (Color(red: 0.99, green: 0.65, blue: 0.40),
                    Color(red: 0.74, green: 0.32, blue: 0.10))

        case .zodiac:
            // Ecliptic blue — the 12+1 zodiacal cycles (Ari, Tau,
            // Gem, Cnc, Leo, Vir, Lib, Sco, Sgr, Cap, Aqr, Psc,
            // and Oph by IAU).
            return (Color(red: 0.42, green: 0.66, blue: 1.00),
                    Color(red: 0.12, green: 0.36, blue: 0.82))

        case .argo:
            // Nautical teal — Argo Navis family: Carina, Puppis,
            // Vela, Pyxis, plus the cluster's hangers-on.
            return (Color(red: 0.40, green: 0.82, blue: 0.86),
                    Color(red: 0.10, green: 0.50, blue: 0.58))

        case .zeus:
            // Regal gold — Boötes, Cygnus, Equuleus, Ursa Major,
            // Ursa Minor, Aquila.
            return (Color(red: 1.00, green: 0.83, blue: 0.30),
                    Color(red: 0.78, green: 0.55, blue: 0.10))

        case .orion:
            // Hunter's cool blue — Orion, Canis Major, Canis Minor,
            // Lepus, Taurus, Scorpius.
            return (Color(red: 0.55, green: 0.65, blue: 1.00),
                    Color(red: 0.18, green: 0.30, blue: 0.75))

        case .orpheus:
            // Lyric purple — Lyra, Cygnus.
            return (Color(red: 0.78, green: 0.55, blue: 0.90),
                    Color(red: 0.42, green: 0.22, blue: 0.62))

        case .none:
            // Modern additions with no mythological tie. Mid-gray,
            // distinguished from `foreverInvisibleGradient` by being
            // a touch warmer / brighter.
            return (Color(red: 0.78, green: 0.78, blue: 0.78),
                    Color(red: 0.45, green: 0.45, blue: 0.45))
        }
    }

    /// Visual override applied when a constellation's centroid
    /// never rises at the observer's latitude. Wins over the
    /// entity colour — a recessive grey that lets the eye skip
    /// past constellations you can't see anyway.
    var constellationForeverInvisibleGradient: (top: Color, bottom: Color) {
        (Color(red: 0.55, green: 0.55, blue: 0.55),
         Color(red: 0.28, green: 0.28, blue: 0.28))
    }

    /// Resolve a constellation's primary mythological entity by
    /// reading its `myths.first` from the JSON-loaded categories.
    /// Falls back to `.none` when the constellation has no myth
    /// listed or the string doesn't match a known case.
    func constellationEntity(of cons: EConstellation) -> POIConstellationEntity {
        guard
            let myth   = ConstellationCategories.shared.category(for: cons)?.myths.first,
            let entity = POIConstellationEntity(rawValue: myth)
        else { return .none }
        return entity
    }
}

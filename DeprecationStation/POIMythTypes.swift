import SwiftUI
import LoreKit

// MARK: - Myth cycle taxonomy (DEPRECATED)
// The constellation-by-Greek-myth colour / grouping system, retired so the
// app reads hemisphere-neutrally — southern constellations (Lacaille /
// Bayer / Hevelius) have no Greek cycle, so colour-coding by myth was a
// northern bias. The per-constellation STORY (catasterism + MythStoryteller)
// lives on in the live app; only this colour-family taxonomy + the cycle
// sheet (`EMythDetailView`) were retired. Preserved here for reference.

/// Mythological cycle a constellation belongs to — pulled from
/// `constellation_categories.json` via `EArtist.constellationMyth(of:)`.
/// Drove the badge GRADIENT so a Hercules constellation read in the same
/// hue as every other Hercules one.
///
/// Raw values match the strings in the JSON `myths` array.
enum POIConstellationMyth: String, CaseIterable, Identifiable {
    case perseus
    case hercules
    case argo
    case zeus
    case orion
    case orpheus
    /// Constellations with no myth in the JSON (Lacaille / Bayer /
    /// Hevelius modern additions, plus Virgo and Libra whose classical
    /// identifications are too fragmented for a single cycle).
    case none

    /// Identity is the JSON key. `Identifiable` so the enum can drive a
    /// `.sheet(item:)` binding for `EMythDetailView`.
    var id: String { rawValue }

    /// One-line tagline per cycle — subtitle in `EMythDetailView`.
    var tagline: String {
        switch self {
        case .perseus:  return String(localized: "Andromeda and the sea-monster")
        case .hercules: return String(localized: "The twelve impossible labours")
        case .argo:     return String(localized: "The voyage for the Golden Fleece")
        case .zeus:     return String(localized: "The father-god's transformations")
        case .orion:    return String(localized: "The hunter and the scorpion")
        case .orpheus:  return String(localized: "The lyre that charmed Hades")
        case .none:     return String(localized: "Constellation cycle")
        }
    }

    /// Localised display title for the cycle (the myth's name).
    var localizedTitle: String {
        switch self {
        case .perseus:  return String(localized: "Perseus")
        case .hercules: return String(localized: "Hercules")
        case .argo:     return String(localized: "Argo")
        case .zeus:     return String(localized: "Zeus")
        case .orion:    return String(localized: "Orion")
        case .orpheus:  return String(localized: "Orpheus")
        case .none:     return String(localized: "Other constellations")
        }
    }
}

/// Top-level kind for a constellation badge. Either it's never visible to
/// this observer (forever-invisible override → gray), or it carries its
/// myth colour.
enum POIConstellationKind {
    case foreverInvisible
    case myth(POIConstellationMyth)
}

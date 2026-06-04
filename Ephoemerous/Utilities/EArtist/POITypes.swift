import SwiftUI
import LoreKit

// MARK: - POI types
// The category / glyph / myth vocabulary shared by every tracked
// celestial object's Apple-Maps-style label. These are standalone
// value types (not `EArtist` members); the styling that maps them to
// colours + thresholds lives in `EArtist+POIStyle.swift`, and the
// drawing in `EArtist+POILabel.swift`.

enum POIGlyph {
    /// SF Symbol drawn via `Image(systemName:)`. Use for "named"
    /// glyphs Apple ships (sun, moon, star, sparkles, etc.).
    case sfSymbol(String)
    /// Raw Unicode character drawn via `Text`. Use for the
    /// astronomical planet glyphs (☿ ♀ ♂ ♃ ♄ ♅ ♆) which SF
    /// Symbols doesn't ship.
    case unicode(String)

    /// Typed builders so glyph call sites reference a `LoreSymbol` /
    /// `ESymbol` case instead of a raw string — one source of truth per
    /// symbol. The canvas path stays string-based (`.sfSymbol`), so this
    /// is pure call-site sugar. Distinct enums, no name collisions, so
    /// `.symbol(.starFill)` (Lore) and `.symbol(.sunMaxFill)` (E) both
    /// resolve via leading-dot.
    static func symbol(_ s: LoreSymbol) -> POIGlyph { .sfSymbol(s.rawValue) }
    static func symbol(_ s: ESymbol)    -> POIGlyph { .sfSymbol(s.rawValue) }
}

/// Shape for the tier-0 "dot" marker — what the POI collapses to
/// when zoomed below `badgeIn`. Most categories want a plain
/// circle; followed stars want a tiny pentagon-squircle so the
/// silhouette already reads as a star at the smallest scale.
enum POIDotShape {
    case circle
    case squircle(corners: Int, bulge: CGFloat)
}

/// Mythological cycle a constellation belongs to — pulled from
/// `constellation_categories.json` via
/// `EArtist.constellationMyth(of:)`. Drives the badge GRADIENT so
/// a Hercules constellation reads in the same hue as every other
/// Hercules one, an Orion one in the hunter hue, etc.
///
/// Raw values match the strings in the JSON `myths` array — keep
/// in sync if you add a new myth there.
///
/// Note: the former `.zodiac` case is gone. The zodiac is a *band
/// of sky*, not a myth cycle — each of its 12+1 constellations has
/// its own narrative home (e.g. Aries → Argo / Golden Fleece;
/// Aquarius → Zeus / Ganymede; Scorpius → Orion).
enum POIConstellationMyth: String, CaseIterable, Identifiable {
    case perseus
    case hercules
    case argo
    case zeus
    case orion
    case orpheus
    /// Constellations with no myth in the JSON (Lacaille / Bayer /
    /// Hevelius modern additions, plus Virgo and Libra whose
    /// classical identifications are too fragmented for a single
    /// cycle).
    case none

    /// Identity is the JSON key. `Identifiable` so the enum can
    /// drive a `.sheet(item:)` binding for `EMythDetailView`.
    var id: String { rawValue }

    /// One-line tagline per cycle — used as the subtitle in
    /// `EMythDetailView` and as the expanded label on the
    /// LearnMyth pill in `DetailActionRow`. Single source of truth
    /// so the two surfaces can never drift out of sync.
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

    /// Localised display title for the cycle (the myth's name). The
    /// `rawValue` stays the canonical JSON key; this is the on-screen name.
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

/// What the constellation *depicts* — the JSON `types` axis.
/// Drives the badge SYMBOL (a hero gets `figure.stand`, an animal
/// gets `pawprint.fill`, an instrument gets `ruler.fill`, …), so
/// the silhouette inside the pill tells you "what is this thing"
/// while the colour tells you "what story does it belong to".
///
/// Raw values match the strings in the JSON `types` array.
enum POIConstellationEntity: String, CaseIterable {
    case hero
    case animal
    case creature
    case object
    case instrument
    case deity
    /// Constellations with no `types` entry — falls back to a
    /// generic glyph.
    case none
}

/// Top-level kind for a constellation badge. Either it's never
/// visible to this observer (forever-invisible override → gray),
/// or it carries its myth colour.
enum POIConstellationKind {
    case foreverInvisible
    case myth(POIConstellationMyth)
}

enum POICategory {
    case constellation(POIConstellationKind)
    case followedStar(EStar)
    /// Proper-named star surfaced as a POI at high zoom. Visually a
    /// quieter sibling of `.followedStar` — same pentagon silhouette
    /// and spectral palette, but later thresholds so they only appear
    /// when the user is clearly zoomed in. Selecting (following) a
    /// named star promotes it to `.followedStar`.
    case namedStar(EStar)
    case sun
    case moon
    case planet(EPlanet)
}

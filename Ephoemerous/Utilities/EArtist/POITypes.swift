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

    /// Localised display name for the entity (the detail/card subtitle).
    /// `rawValue` stays the canonical JSON key; this is the on-screen word.
    var localizedName: String {
        switch self {
        case .hero:       return String(localized: "Hero")
        case .animal:     return String(localized: "Animal")
        case .creature:   return String(localized: "Creature")
        case .object:     return String(localized: "Object")
        case .instrument: return String(localized: "Instrument")
        case .deity:      return String(localized: "Deity")
        case .none:       return String(localized: "Constellation")
        }
    }
}

enum POICategory {
    /// Constellations wear a single neutral tint now — the myth colour
    /// taxonomy is retired (see DeprecationStation), so no payload.
    case constellation
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

import SwiftUI
import LoreKit

// MARK: - POI types
// The category / glyph / myth vocabulary shared by every tracked
// celestial object's Apple-Maps-style label. These are standalone
// value types (not `Artist` members); the styling that maps them to
// colours + thresholds lives in `Artist+POIStyle.swift`, and the
// drawing in `Artist+POILabel.swift`.

enum POIGlyph {
    /// SF Symbol drawn via `Image(systemName:)`. Use for "named"
    /// glyphs Apple ships (sun, moon, star, sparkles, etc.).
    case sfSymbol(String)
    /// Raw Unicode character drawn via `Text`. Use for the
    /// astronomical planet glyphs (☿ ♀ ♂ ♃ ♄ ♅ ♆) which SF
    /// Symbols doesn't ship.
    case unicode(String)

    /// Typed builders so glyph call sites reference a `LoreSymbol` /
    /// `Symbol` case instead of a raw string — one source of truth per
    /// symbol. The canvas path stays string-based (`.sfSymbol`), so this
    /// is pure call-site sugar. Distinct enums, no name collisions, so
    /// `.symbol(.starFill)` (Lore) and `.symbol(.sunMaxFill)` (E) both
    /// resolve via leading-dot.
    static func symbol(_ s: LoreSymbol) -> POIGlyph { .sfSymbol(s.rawValue) }
    static func symbol(_ s: Symbol)    -> POIGlyph { .sfSymbol(s.rawValue) }
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

enum POICategory: Equatable {
    /// Constellations wear a single neutral tint now — the myth colour
    /// taxonomy is retired (see DeprecationStation), so no payload.
    case constellation
    case followedStar(Star)
    /// Proper-named star surfaced as a POI at high zoom. Visually a
    /// quieter sibling of `.followedStar` — same pentagon silhouette
    /// and spectral palette, but later thresholds so they only appear
    /// when the user is clearly zoomed in. Selecting (following) a
    /// named star promotes it to `.followedStar`.
    case namedStar(Star)
    case sun
    case moon
    case planet(Planet)
    /// A crafted thing in orbit (ISS, Hubble) or at L2 (Webb) — one steel
    /// species, set apart from every natural body by its colour.
    case spacecraft(Spacecraft)
    /// A galaxy, cluster or nebula. Deep sky, so it keeps quiet: no badge
    /// at all until well zoomed in, the Messier objects first. The Local
    /// Group galaxies each carry their own face (`galaxy`).
    case deepSky(DeepSkyKind, messier: Bool, galaxy: LocalGalaxy? = nil)
}

/// The three deep-sky badges. Open and globular clusters share one — at
/// badge size the difference doesn't read; the sky's atlas symbol and the
/// subtitle tell them apart. Planetary nebulae and supernova remnants
/// wear the nebula badge.
enum DeepSkyKind: Equatable {
    case galaxy, cluster, nebula
}

/// The six galaxies on the sky — the Local Group members you can point at.
/// Like the planets, each wears its own badge (see `GalaxyFace`): the same
/// diamond outline as every galaxy, with what makes it ITSELF drawn inside.
/// Raw values are the `DeepSkyObject` ids.
enum LocalGalaxy: String, CaseIterable {
    case andromeda  = "M31"
    case triangulum = "M33"
    case m32        = "M32"
    case m110       = "M110"
    case lmc        = "ESO056-115"
    case smc        = "NGC 292"

    /// The galaxy this one is a satellite of, where both are on the sky.
    var host: LocalGalaxy? {
        switch self {
        case .m32, .m110: return .andromeda
        default:          return nil
        }
    }
}

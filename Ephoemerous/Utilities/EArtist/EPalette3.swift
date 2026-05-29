import SwiftUI
import LoreKit

// MARK: - EPalette3 — "Pastel"
//
// Desaturation-forward palette. The sky becomes a warm parchment
// dusk, the gradients become risograph-printed celestial chart, and
// the whole canvas leans toward a calm vintage-stellarium read
// rather than a deep-space data viz. Research notes:
//
//   • Apple Maps in light mode runs on warm cream surfaces with
//     soft-saturation roads. The same instinct applies here — a
//     warm parchment background lets every glyph hold its identity
//     without needing high chroma.
//
//   • Risograph & midcentury celestial charts (Bayer's 1603
//     Uranometria, Cellarius's 1660 Harmonia Macrocosmica, Sky &
//     Telescope's 60s atlases): pastel inks layered on cream paper.
//     The palette reads as scholarly, calm, contemplative — the
//     opposite of Star Walk's electric data viz.
//
//   • Wes Anderson & Pantone "millennial dusk" palettes — blush,
//     dusty peach, powder blue, cornflower, lilac, sage. We map
//     these onto the myth families one-to-one so each cycle keeps
//     its hue identity (Perseus blush, Hercules peach, etc.).
//
//   • Colour science: a warm light-mode background flips the
//     visibility rule from Vivid. On cream, *darker* foregrounds
//     pop, and over-saturated colour reads as childish. Pastel
//     hue+value (L*≈75, C*≈25) keep glyphs legible at small scale
//     without shouting.
//
//   • Cone & user-puck: the green steps DOWN to dusty sage so the
//     "you are here" mark fits the chart's restraint rather than
//     announcing itself with neon. It still wins figure-ground
//     because of the white squircle ring around it.
//
// Not wired. Same swap path as EPalette2 — refactor `EPalette` to a
// protocol and pass any conformer to `EArtist`.

struct EPalette3 {

    typealias Gradient = (top: Color, bottom: Color)

    // MARK: Surfaces

    /// Warm parchment cream — the canvas of a vintage celestial
    /// chart. Slightly warmer than pure paper white to read as
    /// "dusk paper" rather than "blank screen".
    let canvasBackground: Color = Color(red: 0.95, green: 0.93, blue: 0.87)

    // MARK: Grid / axes

    let grid:     Color = Color(red: 0.40, green: 0.35, blue: 0.30).opacity(0.18)
    /// Ecliptic in dusty taupe — the path of the planets traced as
    /// an ink line on parchment.
    let ecliptic: Color = Color(red: 0.55, green: 0.45, blue: 0.38).opacity(0.55)

    // MARK: Horizon

    /// Dusty peach below-horizon — reads as a faded sunset wash.
    let horizonFill:  Color = Color(red: 0.88, green: 0.76, blue: 0.68).opacity(0.55)
    /// Twilight bands in muted rose so the civil / nautical /
    /// astronomical arcs feel like watercolour rings.
    let twilightBand: Color = Color(red: 0.82, green: 0.68, blue: 0.72).opacity(0.55)

    // MARK: Constellations

    /// Dusty periwinkle — the constellation stick figures sit
    /// quietly as if drawn in pencil, then thickened in faded ink.
    let constellationLine:            Color = Color(red: 0.50, green: 0.55, blue: 0.68).opacity(0.45)
    let constellationPlaceholderFill: Color = Color(red: 0.88, green: 0.84, blue: 0.78)

    // MARK: Myth gradients
    //
    // Each cycle keeps its hue identity (so the spatial reading of
    // the sky doesn't shift between palettes), but lifted to L*≈75
    // and dropped to C*≈25 so they read as risograph inks rather
    // than digital signage.

    let perseus              : Gradient = (Color(red: 0.95, green: 0.72, blue: 0.72),
                                            Color(red: 0.78, green: 0.50, blue: 0.55))
    let hercules             : Gradient = (Color(red: 0.98, green: 0.82, blue: 0.65),
                                            Color(red: 0.85, green: 0.62, blue: 0.42))
    let argo                 : Gradient = (Color(red: 0.72, green: 0.88, blue: 0.92),
                                            Color(red: 0.50, green: 0.72, blue: 0.78))
    let zeus                 : Gradient = (Color(red: 0.98, green: 0.90, blue: 0.65),
                                            Color(red: 0.85, green: 0.72, blue: 0.42))
    let orion                : Gradient = (Color(red: 0.78, green: 0.82, blue: 0.95),
                                            Color(red: 0.55, green: 0.62, blue: 0.82))
    let orpheus              : Gradient = (Color(red: 0.85, green: 0.75, blue: 0.92),
                                            Color(red: 0.62, green: 0.50, blue: 0.78))
    let mythNone             : Gradient = (Color(white: 0.82), Color(white: 0.58))
    let mythForeverInvisible : Gradient = (Color(white: 0.65), Color(white: 0.42))

    // MARK: Solar-system gradients

    let sun     : Gradient = (Color(red: 0.98, green: 0.88, blue: 0.55),
                              Color(red: 0.92, green: 0.68, blue: 0.40))
    let moon    : Gradient = (Color(white: 0.92), Color(white: 0.55))

    let mercury : Gradient = (Color(red: 0.88, green: 0.85, blue: 0.80),
                              Color(red: 0.65, green: 0.60, blue: 0.55))
    let venus   : Gradient = (Color(red: 0.98, green: 0.92, blue: 0.78),
                              Color(red: 0.88, green: 0.78, blue: 0.55))
    let mars    : Gradient = (Color(red: 0.95, green: 0.70, blue: 0.62),
                              Color(red: 0.75, green: 0.45, blue: 0.42))
    let jupiter : Gradient = (Color(red: 0.95, green: 0.85, blue: 0.72),
                              Color(red: 0.78, green: 0.62, blue: 0.45))
    let saturn  : Gradient = (Color(red: 0.95, green: 0.88, blue: 0.72),
                              Color(red: 0.78, green: 0.65, blue: 0.42))
    let uranus  : Gradient = (Color(red: 0.78, green: 0.92, blue: 0.92),
                              Color(red: 0.55, green: 0.75, blue: 0.78))
    let neptune : Gradient = (Color(red: 0.72, green: 0.78, blue: 0.92),
                              Color(red: 0.50, green: 0.55, blue: 0.78))

    // MARK: User location puck

    /// Dusty sage — the green steps down to fit the parchment
    /// register. The white squircle ring still wins figure-ground;
    /// the disc just stops shouting.
    let userPuckDisc: Color = Color(red: 0.55, green: 0.75, blue: 0.62)
    let userPuckRing: Color = .white
    let userPuckCone: Color = Color(red: 0.55, green: 0.75, blue: 0.62)

    // MARK: Spectral classes — dark mode
    //
    // (Still useful even in a light-leaning palette — the spectral
    // colours appear on dark detail-sheet backgrounds and inside
    // dark-mode badges.)

    let spectralODark       : Color = Color(red: 0.70, green: 0.78, blue: 0.92)
    let spectralBDark       : Color = Color(red: 0.78, green: 0.85, blue: 0.95)
    let spectralADark       : Color = Color(red: 0.85, green: 0.88, blue: 0.95)
    let spectralFDark       : Color = Color(red: 0.98, green: 0.95, blue: 0.82)
    let spectralGDark       : Color = Color(red: 0.98, green: 0.92, blue: 0.72)
    let spectralKDark       : Color = Color(red: 0.98, green: 0.82, blue: 0.62)
    let spectralMDark       : Color = Color(red: 0.95, green: 0.72, blue: 0.62)
    let spectralUnknownDark : Color = Color(white: 0.72)

    // MARK: Spectral classes — light mode

    let spectralOLight       : Color = Color(red: 0.32, green: 0.42, blue: 0.62)
    let spectralBLight       : Color = Color(red: 0.40, green: 0.52, blue: 0.70)
    let spectralALight       : Color = Color(red: 0.50, green: 0.60, blue: 0.72)
    let spectralFLight       : Color = Color(red: 0.62, green: 0.55, blue: 0.32)
    let spectralGLight       : Color = Color(red: 0.65, green: 0.52, blue: 0.28)
    let spectralKLight       : Color = Color(red: 0.72, green: 0.45, blue: 0.30)
    let spectralMLight       : Color = Color(red: 0.68, green: 0.40, blue: 0.38)
    let spectralUnknownLight : Color = Color(white: 0.48)

    // MARK: Enum-driven accessors
    // See note in EPalette2 — duplicated for self-containment until
    // a protocol unifies the three.

    func myth(_ kind: POIConstellationMyth) -> Gradient {
        switch kind {
        case .perseus:  return perseus
        case .hercules: return hercules
        case .argo:     return argo
        case .zeus:     return zeus
        case .orion:    return orion
        case .orpheus:  return orpheus
        case .none:     return mythNone
        }
    }

    func planet(_ planet: EPlanet) -> Gradient {
        switch planet.name {
        case Strings.Planets.mercury: return mercury
        case Strings.Planets.venus:   return venus
        case Strings.Planets.mars:    return mars
        case Strings.Planets.jupiter: return jupiter
        case Strings.Planets.saturn:  return saturn
        case Strings.Planets.uranus:  return uranus
        case Strings.Planets.neptune: return neptune
        default:                      return (.gray, .gray)
        }
    }

    func spectralDark(_ cls: EHRClass) -> Color {
        switch cls {
        case .O:       return spectralODark
        case .B:       return spectralBDark
        case .A:       return spectralADark
        case .F:       return spectralFDark
        case .G:       return spectralGDark
        case .K:       return spectralKDark
        case .M:       return spectralMDark
        case .unknown: return spectralUnknownDark
        }
    }

    func spectralLight(_ cls: EHRClass) -> Color {
        switch cls {
        case .O:       return spectralOLight
        case .B:       return spectralBLight
        case .A:       return spectralALight
        case .F:       return spectralFLight
        case .G:       return spectralGLight
        case .K:       return spectralKLight
        case .M:       return spectralMLight
        case .unknown: return spectralUnknownLight
        }
    }
}

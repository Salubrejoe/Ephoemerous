import SwiftUI
import LoreKit

// MARK: - EPalette2 — "Vivid"
//
// Saturation-forward palette. Pulls the canvas toward a true-night
// indigo, lets every gradient swing its hue, and treats the
// constellation lines + ecliptic as positive figure-ground colour
// rather than recessive grey grid. Research notes:
//
//   • Apple Maps' dark mode uses semantic high-chroma roads on a
//     near-black surface — that's the structural lesson here: a
//     deep neutral background frees the data to *sing*.
//
//   • Google Maps runs hotter than Apple — warmer roads, more
//     saturated parks. The Vivid palette borrows that "louder is
//     more legible at small scale" instinct for star catalogues
//     where each glyph is ~16 pt tall.
//
//   • Star Walk 2's signature: bright cyan constellation lines on
//     deep navy. We mirror it here — the line carries the figure,
//     not just the connection.
//
//   • Colour science: on a dark canvas, brightness contrast scales
//     visibility faster than hue contrast (Hunt effect). So every
//     "top" gradient stop in Vivid is bumped toward L*≈70 — not
//     just more saturated, but lighter — and "bottom" stops sit at
//     L*≈25-35 to give each gradient real punch.
//
//   • The myth families keep their hue identity (Perseus crimson,
//     Hercules orange, Argo aqua, Zeus gold, Orion blue, Orpheus
//     violet) so the canvas's spatial reading doesn't shift; only
//     the *energy* changes.
//
// Not wired. To try this in the running app, swap `EArtist.palette`
// from an EPalette to call into EPalette2's accessors — either via
// a protocol refactor (the right long-term move) or by copying its
// values over the classic palette temporarily.

struct EPalette2 {

    typealias Gradient = (top: Color, bottom: Color)

    // MARK: Surfaces

    /// True-night indigo. Deeper than the system grey background,
    /// pulls the sky toward a believable astronomy-twilight blue
    /// rather than a UI surface.
    let canvasBackground: Color = Color(red: 0.04, green: 0.05, blue: 0.14)

    // MARK: Grid / axes

    /// Punched up from the classic palette's faded grey so the
    /// stereographic grid reads at glance distance.
    let grid:     Color = Color(white: 0.55).opacity(0.30)
    /// Ecliptic in warm gold — the path of the planets gets its own
    /// hue identity instead of borrowing the secondary grey.
    let ecliptic: Color = Color(red: 1.00, green: 0.80, blue: 0.20).opacity(0.65)

    // MARK: Horizon

    /// Warm rust below-horizon wash — reads as "earth + dust"
    /// rather than the classic neutral grey.
    let horizonFill:  Color = Color(red: 0.55, green: 0.28, blue: 0.18).opacity(0.32)
    /// Twilight bands in coral so civil / nautical / astronomical
    /// each tint as warm dusk arcs against the indigo sky.
    let twilightBand: Color = Color(red: 0.95, green: 0.55, blue: 0.32).opacity(0.45)

    // MARK: Constellations

    /// Electric cyan — Star Walk's signature stick-figure colour.
    let constellationLine:            Color = Color(red: 0.32, green: 0.85, blue: 1.00).opacity(0.50)
    let constellationPlaceholderFill: Color = Color(white: 0.18)

    // MARK: Myth gradients

    let perseus              : Gradient = (Color(red: 1.00, green: 0.32, blue: 0.42),
                                            Color(red: 0.65, green: 0.04, blue: 0.18))
    let hercules             : Gradient = (Color(red: 1.00, green: 0.55, blue: 0.18),
                                            Color(red: 0.80, green: 0.25, blue: 0.05))
    let argo                 : Gradient = (Color(red: 0.20, green: 0.88, blue: 0.92),
                                            Color(red: 0.05, green: 0.45, blue: 0.65))
    let zeus                 : Gradient = (Color(red: 1.00, green: 0.86, blue: 0.10),
                                            Color(red: 0.85, green: 0.55, blue: 0.00))
    let orion                : Gradient = (Color(red: 0.40, green: 0.55, blue: 1.00),
                                            Color(red: 0.10, green: 0.20, blue: 0.85))
    let orpheus              : Gradient = (Color(red: 0.85, green: 0.45, blue: 1.00),
                                            Color(red: 0.45, green: 0.10, blue: 0.78))
    let mythNone             : Gradient = (Color(white: 0.75), Color(white: 0.38))
    let mythForeverInvisible : Gradient = (Color(white: 0.48), Color(white: 0.22))

    // MARK: Solar-system gradients

    let sun     : Gradient = (Color(red: 1.00, green: 0.90, blue: 0.18),
                              Color(red: 1.00, green: 0.45, blue: 0.00))
    let moon    : Gradient = (Color(white: 0.92), Color(white: 0.28))

    let mercury : Gradient = (Color(red: 0.85, green: 0.82, blue: 0.75),
                              Color(red: 0.52, green: 0.48, blue: 0.40))
    let venus   : Gradient = (Color(red: 1.00, green: 0.92, blue: 0.55),
                              Color(red: 0.95, green: 0.70, blue: 0.22))
    let mars    : Gradient = (Color(red: 1.00, green: 0.40, blue: 0.20),
                              Color(red: 0.75, green: 0.08, blue: 0.05))
    let jupiter : Gradient = (Color(red: 1.00, green: 0.82, blue: 0.48),
                              Color(red: 0.85, green: 0.45, blue: 0.20))
    let saturn  : Gradient = (Color(red: 1.00, green: 0.88, blue: 0.42),
                              Color(red: 0.80, green: 0.55, blue: 0.15))
    let uranus  : Gradient = (Color(red: 0.55, green: 0.95, blue: 1.00),
                              Color(red: 0.20, green: 0.65, blue: 0.85))
    let neptune : Gradient = (Color(red: 0.40, green: 0.60, blue: 1.00),
                              Color(red: 0.10, green: 0.25, blue: 0.88))

    // MARK: User location puck

    /// Vibrant emerald — punchier than the classic .green, still
    /// terrestrial in semantic. Against the indigo background it
    /// reads as the brightest non-celestial mark on the canvas,
    /// which is exactly what "you are here" should be.
    let userPuckDisc: Color = Color(red: 0.18, green: 0.88, blue: 0.42)
    let userPuckRing: Color = .white
    let userPuckCone: Color = Color(red: 0.18, green: 0.88, blue: 0.42)

    // MARK: Spectral classes — dark mode

    let spectralODark       : Color = Color(red: 0.42, green: 0.58, blue: 1.00)
    let spectralBDark       : Color = Color(red: 0.55, green: 0.75, blue: 1.00)
    let spectralADark       : Color = Color(red: 0.78, green: 0.88, blue: 1.00)
    let spectralFDark       : Color = Color(red: 1.00, green: 1.00, blue: 0.82)
    let spectralGDark       : Color = Color(red: 1.00, green: 0.95, blue: 0.52)
    let spectralKDark       : Color = Color(red: 1.00, green: 0.75, blue: 0.28)
    let spectralMDark       : Color = Color(red: 1.00, green: 0.48, blue: 0.28)
    let spectralUnknownDark : Color = .gray

    // MARK: Spectral classes — light mode

    let spectralOLight       : Color = Color(red: 0.05, green: 0.20, blue: 0.92)
    let spectralBLight       : Color = Color(red: 0.15, green: 0.40, blue: 0.95)
    let spectralALight       : Color = Color(red: 0.25, green: 0.50, blue: 0.85)
    let spectralFLight       : Color = Color(red: 0.78, green: 0.55, blue: 0.00)
    let spectralGLight       : Color = Color(red: 0.82, green: 0.50, blue: 0.00)
    let spectralKLight       : Color = Color(red: 0.92, green: 0.30, blue: 0.00)
    let spectralMLight       : Color = Color(red: 0.88, green: 0.10, blue: 0.05)
    let spectralUnknownLight : Color = Color(white: 0.35)

    // MARK: Enum-driven accessors
    // Duplicated from EPalette so EPalette2 is self-contained while
    // it's still an exploration. A future "swap the palette in"
    // step should refactor both behind an `EPaletteSource` protocol
    // and drop the duplication.

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

import SwiftUI
import LoreKit

// MARK: - EPalette
// Single source of truth for every colour the canvas paints with.
// `EArtist` holds one instance (`palette`); the per-feature
// extensions (EArtist+Horizon, EArtist+Planets, …) provide
// convenience accessors that proxy into this struct, so layer
// callsites stay short while the actual values live in one place.
//
// EHRClass.color / lightColor also forward here so spectral
// palettes have the same single source of truth.
//
// Use `EPalettePreview` (in `View/Previews/`) to see every entry
// at once — handy for retuning.
struct EPalette {

    typealias Gradient = (top: Color, bottom: Color)

    // MARK: Surfaces

    /// Outermost canvas background — what sits behind every layer.
    let canvasBackground: Color = .secondarySystemBackground

    // MARK: Grid / axes

    /// Faint grid lines (RA / Dec parallels + meridians).
    let grid: Color = .tertiary.opacity(0.2)

    /// Ecliptic squircle stroke.
    let ecliptic: Color = .secondary

    // MARK: Horizon

    /// Below-horizon wash (the `.fillOutsideCurve` colour).
    let horizonFill: Color = .tertiary

    /// Twilight-band strokes (civil / nautical / astronomical).
    let twilightBand: Color = .tertiary

    // MARK: Constellations

    /// Default constellation stick-figure stroke.
    let constellationLine: Color = .tertiary

    /// Placeholder pill that sits in for a constellation label at
    /// the in-between zoom tier.
    let constellationPlaceholderFill: Color = Color(.tertiarySystemFill)

    // MARK: Myth gradients (POI badges)

    let perseus              : Gradient = (Color(red: 0.95, green: 0.45, blue: 0.45),
                                            Color(red: 0.55, green: 0.10, blue: 0.15))
    let hercules             : Gradient = (Color(red: 0.99, green: 0.65, blue: 0.40),
                                            Color(red: 0.74, green: 0.32, blue: 0.10))
    let argo                 : Gradient = (Color(red: 0.40, green: 0.82, blue: 0.86),
                                            Color(red: 0.10, green: 0.50, blue: 0.58))
    let zeus                 : Gradient = (Color(red: 1.00, green: 0.83, blue: 0.30),
                                            Color(red: 0.78, green: 0.55, blue: 0.10))
    let orion                : Gradient = (Color(red: 0.55, green: 0.65, blue: 1.00),
                                            Color(red: 0.18, green: 0.30, blue: 0.75))
    let orpheus              : Gradient = (Color(red: 0.78, green: 0.55, blue: 0.90),
                                            Color(red: 0.42, green: 0.22, blue: 0.62))
    let mythNone             : Gradient = (Color(red: 0.78, green: 0.78, blue: 0.78),
                                            Color(red: 0.45, green: 0.45, blue: 0.45))
    let mythForeverInvisible : Gradient = (Color(red: 0.55, green: 0.55, blue: 0.55),
                                            Color(red: 0.28, green: 0.28, blue: 0.28))

    // MARK: Solar-system gradients

    let sun     : Gradient = (Color(red: 1.00, green: 0.83, blue: 0.30),
                              Color(red: 0.95, green: 0.45, blue: 0.10))
    let moon    : Gradient = (.gray, .black)

    let mercury : Gradient = (Color(red: 0.78, green: 0.78, blue: 0.78),
                              Color(red: 0.45, green: 0.45, blue: 0.45))
    let venus   : Gradient = (Color(red: 1.00, green: 0.95, blue: 0.78),
                              Color(red: 0.92, green: 0.78, blue: 0.45))
    let mars    : Gradient = (Color(red: 1.00, green: 0.50, blue: 0.30),
                              Color(red: 0.78, green: 0.20, blue: 0.10))
    let jupiter : Gradient = (Color(red: 1.00, green: 0.88, blue: 0.70),
                              Color(red: 0.82, green: 0.60, blue: 0.40))
    let saturn  : Gradient = (Color(red: 0.98, green: 0.90, blue: 0.65),
                              Color(red: 0.82, green: 0.68, blue: 0.35))
    let uranus  : Gradient = (Color(red: 0.70, green: 0.95, blue: 0.98),
                              Color(red: 0.35, green: 0.70, blue: 0.80))
    let neptune : Gradient = (Color(red: 0.55, green: 0.70, blue: 1.00),
                              Color(red: 0.20, green: 0.35, blue: 0.78))

    // MARK: User location puck

    let userPuckDisc: Color = .blue
    let userPuckRing: Color = .white
    let userPuckCone: Color = .blue

    // MARK: Spectral classes (stars)
    //
    // Dark-mode = bright pastels readable against the dark sky;
    // light-mode = deep saturated variants for contrast on white.
    // The two pair into a per-class gradient via `spectralGradient`.

    let spectralODark: Color = Color(red: 0.6, green: 0.7, blue: 1.0)
    let spectralBDark: Color = Color(red: 0.7, green: 0.8, blue: 1.0)
    let spectralADark: Color = Color(red: AstroConstants.specA_blue,
                                     green: AstroConstants.specA_green,
                                     blue: 1.0)
    let spectralFDark: Color = Color(red: 1.0, green: 1.0,
                                     blue: AstroConstants.specF_blue)
    let spectralGDark: Color = Color(red: 1.0, green: 1.0, blue: 0.8)
    let spectralKDark: Color = Color(red: 1.0,
                                     green: AstroConstants.specK_green,
                                     blue: 0.6)
    let spectralMDark: Color = Color(red: 1.0, green: 0.7, blue: 0.5)
    let spectralUnknownDark: Color = .gray

    let spectralOLight: Color = Color(red: 0.10, green: 0.25, blue: 0.80)
    let spectralBLight: Color = Color(red: 0.22, green: 0.42, blue: 0.85)
    let spectralALight: Color = Color(red: 0.30, green: 0.50, blue: 0.75)
    let spectralFLight: Color = Color(red: 0.68, green: 0.58, blue: 0.05)
    let spectralGLight: Color = Color(red: 0.72, green: 0.55, blue: 0.00)
    let spectralKLight: Color = Color(red: 0.80, green: 0.36, blue: 0.05)
    let spectralMLight: Color = Color(red: 0.76, green: 0.15, blue: 0.10)
    let spectralUnknownLight: Color = Color(white: 0.38)

    // MARK: - Enum-driven accessors

    /// Constellation myth → badge gradient.
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

    /// Planet → badge gradient. Matches on `EPlanet.name` against
    /// `Strings.Planets.*`, with `(.gray, .gray)` for an unrecognised
    /// name (defensive — shouldn't happen for the canonical seven).
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

    /// Spectral class → dark-mode colour (the value `EHRClass.color`
    /// returns).
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

    /// Spectral class → light-mode colour (the value
    /// `EHRClass.lightColor` returns).
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

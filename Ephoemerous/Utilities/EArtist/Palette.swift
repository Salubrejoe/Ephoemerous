import SwiftUI
import LoreKit

// MARK: - Palette
// Single source of truth for every colour the canvas paints with.
//
// As of the asset-catalog migration, the COLOUR VALUES live in
// `Assets.xcassets/Palette/…` — one colour set per leaf colour, each
// with a Light + Dark variant you can see and tune side-by-side in
// Xcode's inspector. This struct holds no RGB any more; it just names
// the asset colours and keeps the LOGIC the catalog can't express:
//   • enum → colour dispatch (myth / planet / spectral class)
//   • gradient assembly (top + bottom asset pair)
//   • opacity / derived-colour maths
//
// `Artist` holds one instance (`palette`); the per-feature extensions
// (Artist+Horizon, Artist+Planets, …) proxy into it so layer callsites
// stay short. `HRClass.color` / `.lightColor` also forward here.
//
struct Palette {

    typealias Gradient = (top: Color, bottom: Color)

    // Asset colours are organised into folders in the catalog, but
    // colour-set NAMES are globally unique, so each is addressed by name
    // alone — no folder path. Alpha (for grid / horizon / twilight) is
    // baked into the asset, so callers that previously did `.opacity(…)`
    // get the right alpha for free.

    // MARK: Surfaces

    /// Outermost canvas background — what sits behind every layer.
    let canvasBackground: Color = Color("canvasBackground")

    /// Aim sky-wash tint — the blue the night sky lifts toward where the
    /// phone is pointed (`SkyAimWashLayer`). Stored opaque; alpha is
    /// applied at draw time via the blob opacity + horizon fade.
    let skyAim: Color = Color("skyAim")

    // MARK: Grid / axes

    /// Faint grid lines (RA / Dec parallels + meridians).
    let grid: Color = Color("grid")

    /// Ecliptic squircle stroke.
    let ecliptic: Color = Color("ecliptic")

    // MARK: Horizon

    /// Below-horizon wash (the `.fillOutsideCurve` colour).
    let horizonFill: Color = Color("horizonFill")

    /// Twilight-band strokes (civil / nautical / astronomical).
    let twilightBand: Color = Color("twilightBand")

    // MARK: Constellations

    /// Default constellation stick-figure stroke.
    let constellationLine: Color = Color("constellationLine")

    /// Placeholder pill that sits in for a constellation label at the
    /// in-between zoom tier.
    let constellationPlaceholderFill: Color = Color("placeholderFill")

    // MARK: Myth gradients (POI badges)

    let perseus              : Gradient = (Color("mythPerseusTop"),  Color("mythPerseusBottom"))
    let hercules             : Gradient = (Color("mythHerculesTop"), Color("mythHerculesBottom"))
    let argo                 : Gradient = (Color("mythArgoTop"),     Color("mythArgoBottom"))
    let zeus                 : Gradient = (Color("mythZeusTop"),     Color("mythZeusBottom"))
    let orion                : Gradient = (Color("mythOrionTop"),    Color("mythOrionBottom"))
    let orpheus              : Gradient = (Color("mythOrpheusTop"),  Color("mythOrpheusBottom"))
    let mythNone             : Gradient = (Color("mythNoneTop"),     Color("mythNoneBottom"))
    let mythForeverInvisible : Gradient = (Color("mythForeverInvisibleTop"),
                                            Color("mythForeverInvisibleBottom"))

    // MARK: Solar-system gradients

    let sun     : Gradient = (Color("bodySunTop"),     Color("bodySunBottom"))
    let moon    : Gradient = (Color("bodyMoonTop"),    Color("bodyMoonBottom"))
    let mercury : Gradient = (Color("bodyMercuryTop"), Color("bodyMercuryBottom"))
    let venus   : Gradient = (Color("bodyVenusTop"),   Color("bodyVenusBottom"))
    let mars    : Gradient = (Color("bodyMarsTop"),    Color("bodyMarsBottom"))
    let jupiter : Gradient = (Color("bodyJupiterTop"), Color("bodyJupiterBottom"))
    let saturn  : Gradient = (Color("bodySaturnTop"),  Color("bodySaturnBottom"))
    let uranus  : Gradient = (Color("bodyUranusTop"),  Color("bodyUranusBottom"))
    let neptune : Gradient = (Color("bodyNeptuneTop"), Color("bodyNeptuneBottom"))

    // MARK: User location puck

    let userPuckDisc: Color = Color("puckDisc")
    let userPuckRing: Color = Color("puckRing")
    let userPuckCone: Color = Color("puckCone")

    // MARK: Spectral classes (stars)
    //
    // Each class is ONE adaptive asset colour (Light + Dark in the
    // catalog), so a star's tint follows the system appearance instead
    // of the old hand-split color / lightColor pair. The followed-star
    // POI badge still wants a top→bottom GRADIENT, so we derive the
    // darker bottom stop from the adaptive colour at draw time — see
    // `spectralGradient`.

    /// Spectral class → its adaptive asset colour.
    func spectral(_ cls: HRClass) -> Color {
        switch cls {
        case .O:       return Color("spectralO")
        case .B:       return Color("spectralB")
        case .A:       return Color("spectralA")
        case .F:       return Color("spectralF")
        case .G:       return Color("spectralG")
        case .K:       return Color("spectralK")
        case .M:       return Color("spectralM")
        case .unknown: return Color("spectralUnknown")
        }
    }

    /// How much darker the followed-star badge's bottom stop sits below
    /// its top — a mix toward black. Replaces the old "dark colour on
    /// top, light colour on bottom" trick with a single hue that ramps
    /// pale→deep, so the badge reads as one species in either appearance.
    var spectralGradientDarken: Double { 0.92 }

    /// Spectral class → followed-star badge gradient. Top is the
    /// adaptive class colour; bottom is the same colour mixed toward
    /// black so it reads as a lit sphere rather than two stacked tints.
    func spectralGradient(_ cls: HRClass) -> Gradient {
        let bottom = spectral(cls)
        let top    = Color.bodySunTop
        return (top, bottom)
    }

    // MARK: Spectral back-compat accessors
    //
    // `HRClass.color` / `.lightColor` forward here. Both now resolve to
    // the SAME adaptive asset colour (the catalog handles light vs dark),
    // so the old "two hardcoded variants" split is gone — the mode swap
    // is the system's job now.

    /// Was the dark-mode variant; now the adaptive class colour.
    func spectralDark(_ cls: HRClass) -> Color { spectral(cls) }

    /// Was the light-mode variant; now the same adaptive class colour.
    func spectralLight(_ cls: HRClass) -> Color { spectral(cls) }

    // MARK: - Enum-driven accessors
    // (Constellation `myth(_:)` accessor moved to DeprecationStation with
    //  the retired myth taxonomy; the per-cycle colour data stays here.)

    /// Planet → badge gradient. Matches on `Planet.name` against
    /// `Strings.Planets.*`, with a grey fallback for an unrecognised
    /// name (defensive — shouldn't happen for the canonical seven).
    func planet(_ planet: Planet) -> Gradient {
        switch planet.name {
        case Strings.Planets.mercury: return mercury
        case Strings.Planets.venus:   return venus
        case Strings.Planets.mars:    return mars
        case Strings.Planets.jupiter: return jupiter
        case Strings.Planets.saturn:  return saturn
        case Strings.Planets.uranus:  return uranus
        case Strings.Planets.neptune: return neptune
        default:                      return mythNone
        }
    }
}

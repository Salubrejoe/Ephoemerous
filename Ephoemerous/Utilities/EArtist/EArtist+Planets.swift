import SwiftUI

// MARK: - Planets
// Each planet's POI badge gets the body's astronomical Unicode
// glyph — SF Symbols doesn't ship the standard planet symbols, so
// we drop the Unicode character into `POIGlyph.unicode(…)` and let
// `drawPOILabel` render it as `Text` inside the squircle. The
// historical `drawPlanet` (filled disc + tinted glow + sibling
// label) is gone; if it comes back later it lives in git history.
extension EArtist {

    /// Astronomical Unicode glyph for a planet (☿ ♀ ♂ ♃ ♄ ♅ ♆).
    /// Matched by `.name` against `Strings.Planets` — keeps the
    /// lookup robust to a planet's display string changing.
    func planetGlyph(_ planet: EPlanet) -> String {
        switch planet.name {
        case Strings.Planets.mercury: return "☿"
        case Strings.Planets.venus:   return "♀"
        case Strings.Planets.mars:    return "♂"
        case Strings.Planets.jupiter: return "♃"
        case Strings.Planets.saturn:  return "♄"
        case Strings.Planets.uranus:  return "♅"
        case Strings.Planets.neptune: return "♆"
        default:                       return "•"
        }
    }

    /// Top + bottom colours for a planet's POI badge gradient. Hand-
    /// picked to read as the body's "canonical" tint at moderate
    /// saturation — lighter at the top so the linear gradient gives
    /// the same embossed look every other badge has.
    func planetGradient(_ planet: EPlanet) -> (top: Color, bottom: Color) {
        switch planet.name {
        case Strings.Planets.mercury:
            return (Color(red: 0.78, green: 0.78, blue: 0.78),
                    Color(red: 0.45, green: 0.45, blue: 0.45))
        case Strings.Planets.venus:
            return (Color(red: 1.00, green: 0.95, blue: 0.78),
                    Color(red: 0.92, green: 0.78, blue: 0.45))
        case Strings.Planets.mars:
            return (Color(red: 1.00, green: 0.50, blue: 0.30),
                    Color(red: 0.78, green: 0.20, blue: 0.10))
        case Strings.Planets.jupiter:
            return (Color(red: 1.00, green: 0.88, blue: 0.70),
                    Color(red: 0.82, green: 0.60, blue: 0.40))
        case Strings.Planets.saturn:
            return (Color(red: 0.98, green: 0.90, blue: 0.65),
                    Color(red: 0.82, green: 0.68, blue: 0.35))
        case Strings.Planets.uranus:
            return (Color(red: 0.70, green: 0.95, blue: 0.98),
                    Color(red: 0.35, green: 0.70, blue: 0.80))
        case Strings.Planets.neptune:
            return (Color(red: 0.55, green: 0.70, blue: 1.00),
                    Color(red: 0.20, green: 0.35, blue: 0.78))
        default:
            return (.gray, .gray)
        }
    }

    /// Still used by `StarsLayer` margin checks elsewhere — kept
    /// even though the badge no longer reads magnitude visually.
    func planetRadius(_ planet: EPlanet) -> CGFloat {
        CGFloat(max(AstroConstants.planetDotMinR,
                    (AstroConstants.planetDotScale - planet.baseMagnitude) * AstroConstants.planetDotFactor)) / 2
    }
}

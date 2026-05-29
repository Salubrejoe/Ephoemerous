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

    /// Top + bottom colours for a planet's POI badge gradient. The
    /// hex values live in `EPalette`; this wrapper exists so the
    /// `POILabel` switch keeps calling a friendly EArtist method.
    func planetGradient(_ planet: EPlanet) -> (top: Color, bottom: Color) {
        palette.planet(planet)
    }

}

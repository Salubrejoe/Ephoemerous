import SwiftUI

// MARK: - Planets
// Each planet's POI badge gets the body's astronomical Unicode
// glyph — SF Symbols doesn't ship the standard planet symbols, so
// we drop the Unicode character into `POIGlyph.unicode(…)` and let
// `drawPOILabel` render it as `Text` inside the squircle. The
// historical `drawPlanet` (filled disc + tinted glow + sibling
// label) is gone; if it comes back later it lives in git history.
extension Artist {

    /// Astronomical Unicode glyph for a planet (☿ ♀ ♂ ♃ ♄ ♅ ♆).
    /// Matched by `.name` against `Strings.Planets` — keeps the
    /// lookup robust to a planet's display string changing.
    func planetGlyph(_ planet: Planet) -> String {
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
    /// hex values live in `Palette`; this wrapper exists so the
    /// `POILabel` switch keeps calling a friendly Artist method.
    func planetGradient(_ planet: Planet) -> (top: Color, bottom: Color) {
        palette.planet(planet)
    }

    // MARK: Saturn's rings  ▼ TWEAK HERE ▼
    // See `SaturnRings`. Ellipse sizes are full width × height as fractions
    // of the badge diameter: the outer edge spans twice the globe.

    /// Does this badge wear Saturn's rings?
    func poiHasRings(_ category: POICategory) -> Bool {
        if case .planet(let p) = category { return p.name == Strings.Planets.saturn }
        return false
    }

    var saturnRingOuter:   CGSize { CGSize(width: 2.0,   height: 0.764) }
    var saturnRingInner:   CGSize { CGSize(width: 1.345, height: 0.445) }
    var saturnCassini:     CGSize { CGSize(width: 1.736, height: 0.636) }
    var saturnRingTilt:    Angle  { .degrees(-18) }
    /// How far the rings reach past the badge's trailing edge, as a
    /// fraction of its diameter — the name shifts right by this much.
    var saturnRingOverhang: CGFloat { 0.46 }

    /// Ring band: paler cream than the globe so the two separate at
    /// badge size, brightest across the middle like sunlit ice.
    var saturnRingGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.84, green: 0.75, blue: 0.55),
                                Color(red: 0.98, green: 0.93, blue: 0.82),
                                Color(red: 0.84, green: 0.75, blue: 0.55)],
                       startPoint: .leading, endPoint: .trailing)
    }

}

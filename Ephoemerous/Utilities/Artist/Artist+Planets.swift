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

    // MARK: Badge size  ▼ TWEAK HERE ▼
    /// Venus (by far the brightest) and Jupiter (the biggest) step up a
    /// size; the rest share the standard planet badge.
    func planetBadgeSize(_ planet: Planet) -> CGFloat {
        switch planet.name {
        case Strings.Planets.venus, Strings.Planets.jupiter: return 13
        default:                                             return 11
        }
    }

    /// Venus glows a little harder — brilliance is its character.
    func planetGlowBoost(_ planet: Planet) -> CGFloat {
        planet.name == Strings.Planets.venus ? 1.4 : 1
    }

    // MARK: Surfaces  ▼ TWEAK HERE ▼  (see `PlanetSurface`)

    enum PlanetSurfaceKind { case venusPhase, jupiterBands, marsCap, none }

    func planetSurface(_ category: POICategory) -> PlanetSurfaceKind {
        guard case .planet(let p) = category else { return .none }
        switch p.name {
        case Strings.Planets.venus:   return .venusPhase
        case Strings.Planets.jupiter: return .jupiterBands
        case Strings.Planets.mars:    return .marsCap
        default:                      return .none
        }
    }

    /// Thinnest crescent Venus is drawn at — below this it would be
    /// thinner than its own casing and vanish.
    var venusMinimumLit: Double { 0.14 }
    /// Venus's night side.
    var venusNight: Color { .black }

    /// How far the globe is tipped toward us — sets how much the bands curve.
    var jupiterTilt:         Angle  { .degrees(12) }
    var jupiterPoleLatitude: Double { 42 }
    var jupiterPole:         Color  { Color(red: 150/255, green: 120/255, blue: 100/255).opacity(0.55) }
    var jupiterLimb:         Color  { Color(red:  60/255, green:  35/255, blue:  20/255).opacity(0.42) }

    struct PlanetBand { let north, south: Double; let color: Color }

    /// Bands north → south. Sky size keeps the bright equator and the two
    /// great belts; the promoted pin adds the thin temperate belts and the
    /// streaks inside the great ones.
    func jupiterBands(fullDetail: Bool) -> [PlanetBand] {
        func c(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
            Color(red: r / 255, green: g / 255, blue: b / 255).opacity(a)
        }
        var bands = [
            PlanetBand(north:   7, south:  -7, color: c(255, 246, 228, 0.55)),  // equatorial zone
            PlanetBand(north:  19, south:   7, color: c(168,  92,  52, 0.78)),  // NEB, rustier
            PlanetBand(north:  -8, south: -21, color: c(140,  88,  60, 0.74)),  // SEB, browner
        ]
        if fullDetail {
            bands += [
                PlanetBand(north:  31,   south:  26,   color: c(150, 105,  80, 0.50)),  // NTB
                PlanetBand(north: -27,   south: -32,   color: c(150, 105,  80, 0.45)),  // STB
                PlanetBand(north:  14.5, south:  12.5, color: c(235, 190, 150, 0.45)),  // NEB streak
                PlanetBand(north: -13,   south: -14.5, color: c(110,  62,  40, 0.45)),  // SEB streak
                PlanetBand(north: -17,   south: -18.2, color: c(230, 195, 160, 0.40)),  // SEB streak
            ]
        }
        return bands
    }

    var jupiterSpotLatitude:        Double  { -22 }
    /// East of the central meridian, as a fraction of the radius.
    var jupiterSpotLongitudeOffset: CGFloat { 0.32 }
    var jupiterSpot:       Color { Color(red: 206/255, green: 96/255, blue: 66/255) }
    var jupiterSpotRim:    Color { Color(red: 120/255, green: 48/255, blue: 30/255).opacity(0.7) }
    var jupiterSpotHollow: Color { Color(red: 255/255, green: 236/255, blue: 210/255).opacity(0.6) }

    var marsCap: Color { Color(red: 250/255, green: 248/255, blue: 244/255) }

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

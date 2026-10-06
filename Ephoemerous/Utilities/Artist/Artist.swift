import SwiftUI
import simd

// MARK: - Artist
// Visual style centre for every layer drawn on the celestial canvas.
// All tunable knobs and draw helpers live in per-layer extensions
// (`Artist+Grid.swift`, `Artist+Sun.swift`, etc.) — this file is
// just the entry point and shared singleton.
//
// Colour values are owned by `Palette` (see `Palette.swift`). The
// per-feature extensions on Artist (`Artist+Horizon`,
// `Artist+Planets`, …) provide convenience accessors that proxy
// into `palette`, so layer callsites stay short while every actual
// hex value lives in one file — the asset catalogue is where you see
// them all for visual tuning.
struct Artist {
    static let shared = Artist()

    /// Single source of truth for every colour on the canvas. The
    /// per-feature extensions read from here.
    let palette = Palette()
    
    var canvasBackground : Color { palette.canvasBackground }

    /// How far the visible sky sits below `canvasBackground` — the veil
    /// inside the horizon. ▼ TWEAK the sky's depth here ▼
    var skyDepth : Double { 0.10 }
    /// The visible sky's own colour: the canvas, veiled. Anything drawn
    /// "in sky colour" on the ground reads as a window back onto it.
    var skyColor : Color  { canvasBackground.mix(with: .black, by: skyDepth) }
    
    /// The equatorial graticule is scaffolding, not sky — it should read as
    /// a whisper beneath the stars. Dimmed HERE rather than in the asset
    /// because `palette.grid` is shared with the horizon + twilight rings,
    /// which carry their own (louder) opacities. ▼ TWEAK ▼
    var gridOpacity : Double { 0.55 }
    var gridColor   : Color  { palette.grid.opacity(gridOpacity) }
    var gridWidth   : Double { 0.1 }
    /// The graticule's own extra hush, on top of `gridOpacity` — applied
    /// in `CelestialGridCanvas` only, so the horizon and twilight labels
    /// that share `gridColor` keep their weight. ▼ TWEAK ▼
    var celestialGridVolume: Double { 0.6 }
    
    /// The one ink the sky writes in — stars, graticule, constellation
    /// names, Bayer letters, figure lines. A cool near-white (OKLCH L .985,
    /// C .006, h 262: the A-class white of the star ramp), so nothing on the
    /// map is the hue-less pure white that sits apart from the navy. The text
    /// and line ladders are the system's own alphas (.60 / .30), kept so
    /// contrast is unchanged — only the hue is ours.
    var ink          : Color { palette.starField }
    var inkSecondary : Color { ink.opacity(0.60) }
    var inkTertiary  : Color { ink.opacity(0.30) }

    /// The generic star field. White in dark mode, at full strength — the
    /// per-star magnitude opacity below is the only thing that dims it.
    var starColor : Color { palette.starField }
    /// The untappable field's ink — the star colour, hushed, so the
    /// pentagons and badges (the stars you can touch) lead. This is a named
    /// star still waiting for its own mark: tappable once you zoom in.
    /// ▼ TWEAK ▼
    var fieldStarColor: Color { starColor.opacity(0.78) }
    /// Stars with no name, which no zoom will ever make tappable — quieter
    /// still, so the field recedes behind the stars that can become marks.
    /// ▼ TWEAK ▼
    var anonymousStarColor: Color { starColor.opacity(0.55) }

    // MARK: - User location
    // The puck and aim cone are retired (DeprecationStation/PuckAndConeOverlay);
    // their constants went with them — see `PaletteRetired`.
    /// Apple hemisphere globe SF Symbol matched to the observer's longitude
    /// so the puck wears the continent it sits on.
    func userLocationGlobeSymbol(forLongitude lon: Double) -> Symbol {
        var l = lon
        while l >  180 { l -= 360 }
        while l < -180 { l += 360 }
        if l >= -30 && l <  60  { return .globeEuropeAfrica  }
        if l >=  60 && l < 110  { return .globeSouthAsia     }
        if l >= 110 || l < -170 { return .globeAsiaAustralia }
        return .globeAmericas
    }

    // MARK: - Squircle / horizon-rim Lamé params (LocationPickerPanel)
    var horizonBumpCorners : Int     { 12 }
    var horizonBumpBulge   : CGFloat { 2.2 }

    /// Sky-disc clip radius in projection units (AppState+Viewport).
    var clipRadius : Double { 2 * sqrt(3) }

    /// POI text casing border width (POILabelView).
    var poiTextBorderWidth : CGFloat { 1.7 }
}

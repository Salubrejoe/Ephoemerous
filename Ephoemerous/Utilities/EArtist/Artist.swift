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
    
    var gridColor : Color  { palette.grid }
    var gridWidth : Double { 0.1 }
    
    var eclColor : Color  { palette.ecliptic }
    var eclWidth : Double { 0.5 }
    
    var horizonFillColor   : Color  { palette.horizonFill }

    // MARK: - User location (puck + aim cone)
    // Live constants consolidated here from Artist+UserLocation (the draw
    // half of which is deprecated). Read by PuckAndConeOverlay.
    var userPuckSize            : CGFloat { 22 }
    var userPuckConeColor       : Color   { palette.userPuckCone }
    var userPuckConeRadius      : CGFloat { 90 }
    /// Hushed — "you are here" is ambient whisper-tier, and the cone was the
    /// loudest shape on the canvas (metadata louder than the stars it points
    /// at). Length stays honest (tip on the aimed point); only the volume
    /// drops. ▼ TWEAK ▼
    var userPuckConeOpacity     : Double  { 0.16 }
    var userPuckConeMinHalfAngle: Double  { 8 }    // degrees
    var userPuckConeMaxHalfAngle: Double  { 60 }   // degrees
    /// Pitch→length honesty for the aim cone (1 = tip on the aimed point).
    var aimConeLengthGain       : Double  { 1.0 }
    /// Clamp display altitude off the zenith (where azimuth spins).
    var aimConeMaxAltitudeDeg   : Double  { 86 }
    /// Floor at the horizon so the tip doesn't shoot past the rim.
    var aimConeMinAltitudeDeg   : Double  { 0 }

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

import SwiftUI

enum EHRClass: String, CaseIterable {

    case O, B, A, F, G, K, M, unknown

    // MARK: - Colours
    //
    // Both palettes live in `EPalette` so every colour in the app
    // has the same single source of truth. These accessors forward
    // there — keeping the old `star.spectralClass.color` callsites
    // working unchanged.

    /// Dark-mode bright pastel for the spectral class. Used on the
    /// canvas (POI badge glyph tint, favourite heart) where the sky
    /// is dark.
    var color: Color {
        EArtist.shared.palette.spectralDark(self)
    }

    /// Light-mode deep saturated variant for high contrast on white
    /// (detail-sheet tiles, etc.).
    var lightColor: Color {
        EArtist.shared.palette.spectralLight(self)
    }

    // MARK: - Adaptive helper
    func adaptiveColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color : lightColor
    }

    // MARK: - POI badge gradient
    /// Top + bottom colours for the followed-star POI badge: the
    /// adaptive class colour up top, the same hue mixed toward black at
    /// the bottom, so the badge reads as a lit sphere of the class's
    /// colour in either appearance. Derived in `EPalette` from the one
    /// adaptive asset colour (no more dark/light-as-gradient split).
    var badgeGradient: (top: Color, bottom: Color) {
        EArtist.shared.palette.spectralGradient(self)
    }
}

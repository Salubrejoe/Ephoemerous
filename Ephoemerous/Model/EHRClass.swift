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
    /// Top + bottom colours used by the followed-star POI badge so
    /// the badge tints to its spectral class — pale `color` at the
    /// top, deep `lightColor` at the bottom. The two variants were
    /// designed for opposite mode contrasts; pairing them gives a
    /// natural light-to-deep ramp that reads instantly as "this is
    /// a hot blue O" vs "this is a red M dwarf".
    var badgeGradient: (top: Color, bottom: Color) {
        (color, lightColor)
    }
}

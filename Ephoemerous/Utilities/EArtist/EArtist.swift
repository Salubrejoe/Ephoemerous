import SwiftUI
import simd

// MARK: - EArtist
// Visual style centre for every layer drawn on the celestial canvas.
// All tunable knobs and draw helpers live in per-layer extensions
// (`EArtist+Grid.swift`, `EArtist+Sun.swift`, etc.) — this file is
// just the entry point and shared singleton.
//
// Colour values are owned by `EPalette` (see `EPalette.swift`). The
// per-feature extensions on EArtist (`EArtist+Horizon`,
// `EArtist+Planets`, …) provide convenience accessors that proxy
// into `palette`, so layer callsites stay short while every actual
// hex value lives in one file. `EPalettePreview` renders every
// entry for visual tuning.
struct EArtist {
    static let shared = EArtist()

    /// Single source of truth for every colour on the canvas. The
    /// per-feature extensions read from here.
    let palette = EPalette3()
}

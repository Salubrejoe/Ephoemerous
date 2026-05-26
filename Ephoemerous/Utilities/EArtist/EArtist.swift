import SwiftUI
import simd

// MARK: - EArtist
// Visual style centre for every layer drawn on the celestial canvas.
// All tunable knobs and draw helpers live in per-layer extensions
// (`EArtist+Grid.swift`, `EArtist+Sun.swift`, etc.) — this file is
// just the entry point and shared singleton.
//
// Why a struct + `shared` instance rather than a static-only namespace:
// the value-typed instance lets layers thread an `artist` reference
// around without forcing every access through the type name, and it
// keeps the door open to alternate palettes / themes later without a
// mass rename. There are no stored instance properties today — every
// constant is a computed `var` declared in its layer's extension — so
// the singleton is essentially free.
struct EArtist {
    static let shared = EArtist()
}

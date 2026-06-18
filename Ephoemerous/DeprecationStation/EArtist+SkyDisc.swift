import SwiftUI
import LoreKit

// MARK: - Sky disc geometry
// Shared constants describing the projected sky's reach. The
// observer-centred stereographic projection maps the celestial
// sphere onto a finite disc; `clipRadius` is that disc's radius in
// projection units, used by:
//
//   • `EAppState.contentDiscRadius(atScale:)` to compute the
//     viewport rubber-zone bounds (the canvas-derived `defaultScale`
//     formula falls out of this).
//   • `HorizonLayer`'s commented-out chrome-clip lineage (the
//     reference is preserved for posterity but no longer called).
//
// The old `chromeBounds` / `chromePath` / `chromeCorners` /
// `chromeBulge` helpers were retired alongside the clock-mode watch
// chrome — see `DeprecationStation/WatchBackgroundLayer.swift` and
// friends for their history.
extension EArtist {

    /// Disc radius in projection units. The horizon great circle
    /// itself projects to a true circle of radius 2 in pure
    /// stereographic; `2 · √3 ≈ 3.46` overshoots that so the
    /// rubber-band viewport bounds (which use this) leave some room
    /// outside the horizon proper.
    // (clipRadius moved to EArtist.swift)

    /// Bleed past the disc, in points. Survived the chrome
    /// retirement because the viewport-bounds math wants a tiny
    /// margin so the rim isn't a hairline clip seam at high zoom.
    var clipBleed: Double { 8 }
}

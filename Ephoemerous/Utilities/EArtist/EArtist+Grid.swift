import SwiftUI

// MARK: - Grid
// Coordinate grid drawn by `EarthGridLayer` — meridians, parallels,
// pole + RA labels. Thin, desaturated tint so the grid sits behind
// the bright content (sun, moon, planets, stars) without competing.
extension EArtist {

    var gridColor : Color  { .secondary.opacity(0.4) }
    var gridWidth : Double { 0.55 }
}

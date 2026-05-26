import SwiftUI
import LoreKit

// MARK: - Grid
// Visual tuning for the coordinate grid drawn by `EarthGridLayer`
// (meridians, parallels, equator, tropics). Strokes are kept thin and
// desaturated so they sit behind the bright content (sun, moon,
// planets, stars) without competing for attention.
extension EArtist {

    var gridWidth      : Double { 0.55 }
    var gridColor      : Color  { .tertiary }
    var gridBrightness : Double { 0.0 }
}

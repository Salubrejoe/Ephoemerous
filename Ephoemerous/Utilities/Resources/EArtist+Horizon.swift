import SwiftUI

// MARK: - Horizon
// Visual tuning for the horizon rim + twilight bands drawn by
// `HorizonLayer`. The layer owns its own corners / bulge / stroke
// width; these constants are the older shared knobs (still kept so
// fallback / NS-mode rendering can reach for them).
extension EArtist {

    var horizonFillColor  : Color  { .tertiary }
    var sunsetStrokeColor : Color  { .tertiary }
    var sunsetStrokeWidth : Double { 1.0 }
}

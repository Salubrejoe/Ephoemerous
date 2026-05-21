import SwiftUI

// MARK: - Ecliptic
// Visual tuning for the ecliptic squircle band drawn by
// `EclipticLayer`. The layer mostly owns its own constants now — these
// are shared fallback knobs other layers might reach for (e.g. text
// colour matched to the rim).
extension EArtist {

    var eclColor : Color  { sunBorderColor }
    var eclWidth : Double { 1.0 }
}

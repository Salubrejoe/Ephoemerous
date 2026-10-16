import SwiftUI

// MARK: - Nebulae
// The named nebulae each wear their own silhouette, the way the galaxies
// and spacecraft do (see `NebulaGlyph`). First, the planetary nebulae —
// the shells dying stars throw off, lit green-blue by oxygen at the heart
// and red by hydrogen and nitrogen further out:
//   • Ring (M57)           — a tilted donut, teal inside, burning red at its rim
//   • Owl (M97)            — a round aqua face with two dark eyes
//   • Dumbbell (M27)       — a green hourglass, the "apple core", in a rosy oval
//   • Little Dumbbell (M76)— a small pink peanut, tied at the waist
// Then Orion's three, where stars are being born — hydrogen pink, dust
// dark, starlight blue:
//   • Orion (M42)          — a bright heart round the Trapezium, two wings
//                            sweeping south, the dark Fish's Mouth above
//   • De Mairan's (M43)    — a round pink glow hooked by a dark lane, a star
//                            at its heart
//   • M78                  — a blue fan of dust lit by two stars at its tip
// And the two brightest left to the eye:
//   • Carina (NGC 3372)    — a great magenta cloud split by a dark V, Eta
//                            Carinae blazing at its head
//   • Lagoon (M8)          — a long salmon cloud, a dark channel winding
//                            through it, the white Hourglass on one side and
//                            a young cluster's blue stars on the other
// ▼ TWEAK the nebulae here ▼
extension Artist {

    /// Badge width (pt) — the frame the silhouette is fitted into.
    func nebulaBadgeSize(_ n: NamedNebula) -> CGFloat {
        switch n {
        case .orion, .carina: return 17
        case .lagoon:         return 16
        case .dumbbell:       return 14
        case .ring, .owl:     return 13
        case .littleDumbbell: return 12
        case .m78:            return 12
        case .deMairan:       return 10
        }
    }

    /// The paints the silhouettes are built from, deep → bright.
    func nebulaPaint(_ paint: NebulaShapes.Paint) -> (Color, Color) {
        switch paint {
        case .oxygen:   return (p3(0.300, 0.700, 0.660), p3(0.720, 0.985, 0.830))   // the green-blue heart
        case .ringRim:  return (p3(0.660, 0.200, 0.260), p3(1.000, 0.580, 0.380))   // red → amber
        case .ringHole: return (p3(0.150, 0.290, 0.390), p3(0.300, 0.520, 0.600))   // the dim middle
        case .owl:      return (p3(0.240, 0.460, 0.560), p3(0.620, 0.880, 0.900))   // aqua
        case .owlEye:   return (p3(0.070, 0.140, 0.220), p3(0.110, 0.200, 0.290))   // the eyes
        case .halo:     return (p3(0.520, 0.260, 0.360), p3(0.840, 0.500, 0.560))   // the Dumbbell's rosy oval
        case .bowtie:   return (p3(0.680, 0.260, 0.380), p3(1.000, 0.620, 0.640))   // the Little Dumbbell
        case .hydrogen: return (p3(0.680, 0.220, 0.340), p3(1.000, 0.560, 0.620))   // Orion's wings
        case .magenta:  return (p3(0.720, 0.300, 0.480), p3(1.000, 0.680, 0.760))   // De Mairan's
        case .starlit:  return (p3(0.220, 0.380, 0.780), p3(0.700, 0.840, 1.000))   // M78, dust lit blue
        case .dust:     return (p3(0.110, 0.060, 0.090), p3(0.180, 0.100, 0.130))   // dark lanes
        case .carina:   return (p3(0.600, 0.190, 0.380), p3(0.980, 0.520, 0.700))   // Carina's magenta
        case .lagoon:   return (p3(0.720, 0.340, 0.320), p3(1.000, 0.730, 0.620))   // the Lagoon's salmon
        case .etaGlow:  return (p3(1.000, 0.700, 0.420), p3(1.000, 0.900, 0.760))   // Eta Carinae's warm light
        case .youngStar:return (p3(0.700, 0.820, 1.000), p3(0.900, 0.950, 1.000))   // the Lagoon's cluster
        }
    }

    /// Each nebula's main paint — its glow, and its name's colour.
    func nebulaMainPaint(_ n: NamedNebula) -> NebulaShapes.Paint {
        switch n {
        case .ring:           return .ringRim
        case .owl:            return .owl
        case .dumbbell:       return .oxygen
        case .littleDumbbell: return .bowtie
        case .orion:          return .hydrogen
        case .deMairan:       return .magenta
        case .m78:            return .starlit
        case .carina:         return .carina
        case .lagoon:         return .lagoon
        }
    }

    private func p3(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(.displayP3, red: r, green: g, blue: b)
    }
}

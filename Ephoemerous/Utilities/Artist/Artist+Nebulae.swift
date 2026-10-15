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
// ▼ TWEAK the nebulae here ▼
extension Artist {

    /// Badge width (pt) — the frame the silhouette is fitted into.
    func nebulaBadgeSize(_ n: NamedNebula) -> CGFloat {
        switch n {
        case .dumbbell:       return 14
        case .ring, .owl:     return 13
        case .littleDumbbell: return 12
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
        }
    }

    /// Each nebula's main paint — its glow, and its name's colour.
    func nebulaMainPaint(_ n: NamedNebula) -> NebulaShapes.Paint {
        switch n {
        case .ring:           return .ringRim
        case .owl:            return .owl
        case .dumbbell:       return .oxygen
        case .littleDumbbell: return .bowtie
        }
    }

    private func p3(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(.displayP3, red: r, green: g, blue: b)
    }
}

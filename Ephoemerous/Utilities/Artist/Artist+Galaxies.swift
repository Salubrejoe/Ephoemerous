import SwiftUI

// MARK: - Galaxies
// The six Local Group galaxies each wear their own silhouette, the way the
// spacecraft do — a badge, not a replica, drawn from how each one really
// looks (see `GalaxyGlyph`):
//   • Andromeda  — Saturn's grammar: a golden bulge through a long tilted
//                  disc, its front half crossing in front, a dust lane on it
//   • Triangulum — a disc seen half face-on, two bright arms wound across it
//   • M32        — a compact oval in stepped isophotes, a bright core
//   • M110       — a taller oval whose isophotes twist
//   • LMC        — a lumpy cloud with a bright bar and the pink Tarantula
//   • SMC        — a slanted bean with its Wing
//   • Milky Way  — face-on, as no one has ever seen it: a golden bar, two
//                  great arms and two lesser, the Sun a bead on the way out
// Andromeda's two companions are old-star ellipticals, so they take the
// colour of its bulge; the Clouds share a slate.
// ▼ TWEAK the galaxies here ▼
extension Artist {

    /// Badge width (pt) — the frame the silhouette is fitted into. Andromeda
    /// runs wide because its disc is thin: by weight it sits with the
    /// planets, much as Saturn does with its rings.
    func galaxyBadgeSize(_ g: LocalGalaxy) -> CGFloat {
        switch g {
        case .andromeda:  return 20
        case .lmc:        return 16.5
        case .triangulum: return 16
        case .smc:        return 15
        case .m110:       return 12
        case .m32:        return 10.5
        case .milkyWay:   return 19
        }
    }

    /// The paints the silhouettes are built from, deep → bright (bottom →
    /// top of each part; every part is lit from above).
    func galaxyPaint(_ paint: GalaxyShapes.Paint) -> (Color, Color) {
        switch paint {
        case .disc:      return (p3(0.380, 0.360, 0.660), p3(0.735, 0.750, 0.985))   // Andromeda's blue-violet arms
        case .warm:      return (p3(0.850, 0.600, 0.380), p3(0.985, 0.820, 0.580))   // its golden inner disc
        case .bulge:     return (p3(0.920, 0.720, 0.430), p3(1.000, 0.950, 0.820))   // gold → cream
        case .armDisc:   return (p3(0.220, 0.280, 0.600), p3(0.420, 0.520, 0.860))   // Triangulum's disc, between the arms
        case .arm:       return (p3(0.600, 0.740, 1.000), p3(0.880, 0.940, 1.000))   // its arms, young blue suns
        case .core:      return (p3(0.920, 0.860, 0.720), p3(1.000, 0.985, 0.930))   // a nucleus
        case .elliptical:return (p3(0.800, 0.610, 0.500), p3(1.000, 0.900, 0.780))   // M32: old suns
        case .dwarf:     return (p3(0.700, 0.540, 0.560), p3(0.950, 0.830, 0.810))   // M110: dimmer, rosier
        case .cloud:     return (p3(0.420, 0.530, 0.710), p3(0.860, 0.920, 1.000))   // the Large Cloud
        case .smallCloud:return (p3(0.430, 0.570, 0.620), p3(0.860, 0.950, 0.940))   // the Small, a touch greener
        case .bar:       return (p3(0.820, 0.880, 0.970), p3(1.000, 1.000, 1.000))   // the Clouds' bars
        case .nebula:    return (p3(0.900, 0.300, 0.500), p3(1.000, 0.600, 0.750))   // hydrogen pink
        case .homeDisc:  return (p3(0.180, 0.200, 0.420), p3(0.330, 0.360, 0.640))   // the Milky Way's dusky disc
        case .homeArm:   return (p3(0.640, 0.700, 0.960), p3(0.930, 0.950, 1.000))   // its arms, milk-white blue
        }
    }

    /// Each galaxy's main paint — its glow, and its name's colour.
    func galaxyMainPaint(_ g: LocalGalaxy) -> GalaxyShapes.Paint {
        switch g {
        case .andromeda:  return .disc
        case .triangulum: return .arm
        case .m32:        return .elliptical
        case .m110:       return .dwarf
        case .lmc:        return .cloud
        case .smc:        return .smallCloud
        case .milkyWay:   return .homeArm
        }
    }

    /// Andromeda's dust lanes, M110's dust patches.
    var galaxyDust: Color { p3(0.300, 0.190, 0.170) }

    private func p3(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(.displayP3, red: r, green: g, blue: b)
    }
}

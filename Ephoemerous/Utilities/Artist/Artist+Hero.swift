import SwiftUI

// MARK: - Detail hero  ▼ TWEAK HERE ▼
// See `HeroBanner` / `SkyHeroView`.
extension Artist {

    /// Banner height. Short enough that the phone's third-height sheet
    /// still shows the title and the action row under it.
    var heroHeight: CGFloat { 150 }

    /// Field shown above and below a planet's or a spacecraft's position.
    var heroBodyHalfField:     Double { 12 * .pi / 180 }
    /// How wide the Sun's and Moon's discs are drawn: as wide as Saturn's
    /// hero, rings included. Their field zooms to make that true scale.
    var heroLuminaryDiameter: CGFloat {
        poiStyle(for: .planet(.saturn)).badgeSize * poiSelectScale * saturnRingOuter.width
    }

    /// Mean apparent diameters, radians.
    var sunAngularDiameter:  Double { 0.533 * .pi / 180 }
    var moonAngularDiameter: Double { 0.518 * .pi / 180 }

    /// The night behind every rendered sky hero: the app's own sky at the
    /// top (the hero is a window onto it), warming a notch toward dusk at
    /// the foot — the same graphite-blue family, hue turned ~14° and a
    /// little lifted, not the old saturated violet. ▼ TWEAK the dusk here ▼
    var skyHeroGround: LinearGradient {
        LinearGradient(colors: [skyColor,
                                Color(.displayP3, red: 0.104, green: 0.121, blue: 0.200)],   // OKLCH L .245  C .042  h 272
                       startPoint: .top, endPoint: .bottom)
    }
}

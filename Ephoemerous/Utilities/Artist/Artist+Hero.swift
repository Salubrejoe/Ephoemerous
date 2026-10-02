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

    /// The night behind every rendered sky hero: deep navy at the top,
    /// warming to dusk violet at the foot.
    var skyHeroGround: LinearGradient {
        LinearGradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.10),
                                Color(red: 0.09, green: 0.07, blue: 0.20)],
                       startPoint: .top, endPoint: .bottom)
    }
}

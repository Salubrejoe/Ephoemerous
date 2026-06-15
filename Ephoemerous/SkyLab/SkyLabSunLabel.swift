import SwiftUI
import simd

// MARK: - SkyLabSunLabel
// The Sun as a NATIVE SwiftUI overlay — the half of the experiment that
// proves the win: a `Text` rasterises its glyphs once into a layer, and
// the shared parent transform composites it for free, with zero
// per-frame glyph work. Positioned at the Sun's projected screen point
// using the SAME committed camera the grid Canvas draws with — so the two
// renderers share one coordinate truth and the parent transform moves
// them in lockstep.
struct SkyLabSunLabel: View {
    let camera: SkyLabCamera
    let date:   Date
    /// Live pinch magnification of the shared parent transform. We
    /// counter-scale by its inverse so the badge keeps a constant SCREEN
    /// size while still tracking its sky point — see the size note below.
    var pinch:  CGFloat = 1

    private var sunScreen: CGPoint? {
        let lambda = ESunPosition.eclipticLongitude(for: date)
        let eq     = SIMD3<Double>.eclipticPoint(lambda: lambda)
        return camera.screen(equatorial: eq)
    }

    var body: some View {
        if let sc = sunScreen {
            // Reusable Apple-Maps POI label (badge + name) — anchored on
            // the badge so `.position(sc)` lands it on the Sun.
            POILabelView(category: .sun,
                         glyph:    .sfSymbol("sun.max.fill"),
                         text:     Strings.Bodies.sun)
                // Counter the parent's live `.scaleEffect(pinch)` about the
                // badge's own centre: net size = 1 (constant on screen),
                // while the parent still moves it with the zoom so it stays
                // glued to the Sun. Applied BEFORE `.position`.
                .scaleEffect(1 / pinch)
                .position(sc)
        }
    }
}

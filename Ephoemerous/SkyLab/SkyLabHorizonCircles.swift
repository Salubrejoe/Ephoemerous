import SwiftUI

// MARK: - SkyLabHorizonCircles
// The horizon + twilight rings. In the observer-centred stereographic
// projection, every constant-ALTITUDE circle (almucantar) maps to a TRUE
// circle centred on the zenith — and the zenith is the projection origin,
// which `camera.screen(.zero)` puts at the canvas centre. So these are
// the one cartographic layer that's cleanest as native `Circle`s (no
// arc-visibility math, unlike the equatorial grid): concentric strokes,
// no fill, riding the parent transform.
//
// Projection radius for altitude a: ρ = 2·cos a / (1 + sin a)
//   horizon (0°)        → 2.00   (boundary of the visible sky)
//   civil  (−6°)        → 2.22
//   nautical (−12°)     → 2.47   (below the horizon → larger rings)
//   astronomical (−18°) → 2.75
struct SkyLabHorizonCircles: View {

    let camera: SkyLabCamera

    private struct Band {
        let altitude:  Angle
        let lineWidth: CGFloat
        let opacity:   Double
    }

    private static let bands: [Band] = [
        .init(altitude: .degrees(  0), lineWidth: 1.1, opacity: 0.55),  // horizon
//        .init(altitude: .degrees( -6), lineWidth: 0.7, opacity: 0.1),  // civil
//        .init(altitude: .degrees(-12), lineWidth: 0.7, opacity: 0.1),  // nautical
//        .init(altitude: .degrees(-18), lineWidth: 0.7, opacity: 0.1),  // astronomical
    ]

    var body: some View {
        // Zenith = projection origin = canvas centre.
        let zenith = camera.screen(.zero)
        let artist = EArtist.shared
        ZStack {
            ForEach(0 ..< Self.bands.count, id: \.self) { i in
                let band = Self.bands[i]
                let r    = Self.projectionRadius(band.altitude) * camera.scale
                Circle()
                    .stroke(artist.gridColor
                        .opacity(band.opacity),
                            lineWidth: band.lineWidth)
                    .frame(width: r * 2, height: r * 2)
                    .position(zenith)
            }
        }
    }

    /// Stereographic screen radius (projection units) of the
    /// constant-`altitude` circle.
    private static func projectionRadius(_ altitude: Angle) -> CGFloat {
        let a = altitude.radians
        return CGFloat(2 * cos(a) / (1 + sin(a)))
    }
}

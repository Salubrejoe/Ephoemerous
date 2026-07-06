import SwiftUI
import LoreKit

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
struct EarthGridOverlay: View {

    let camera: SkyCamera

    private struct Band {
        let altitude:  Angle
        let lineWidth: CGFloat
        let opacity:   Double
    }

    private static let horizon: Band = .init(
        altitude: .degrees(0),
        lineWidth: 1.1,
        opacity: 0.55
    )
    
    private static let bands: [Band] = [
        .init(altitude: .degrees(  0), lineWidth: 1.1, opacity: 0.55),
        .init(altitude: .degrees( -6), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-12), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-18), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-24), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-30), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-36), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-42), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-48), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(-54), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(-60), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(-66), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(-72), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(-78), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(-84), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(-90), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(  0), lineWidth: 1.1, opacity: 0.55),
//        .init(altitude: .degrees( 6), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(12), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(18), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(24), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(30), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(36), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(42), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(48), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(54), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(60), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(66), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(72), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(78), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(84), lineWidth: 0.7, opacity: 0.1),
//        .init(altitude: .degrees(90), lineWidth: 0.7, opacity: 0.1),
    ]

    var body: some View {
        // Zenith = projection origin = canvas centre.
        let zenith = camera.screen(.zero)

        ZStack {
            ForEach(0 ..< Self.bands.count, id: \.self) { i in
                let band = Self.bands[i]
                let r    = Self.projectionRadius(band.altitude) * camera.scale
                // A rectangle covering the whole (oversized) canvas with a
                // circular hole of radius `r` punched at the zenith. The
                // even-odd fill is what turns the inner circle into a HOLE:
                // rect winding + circle winding cancel inside the circle.
                // Stacked per band, the wash accumulates OUTSIDE each ring,
                // so the sky reads clear inside the horizon and thickens
                // toward / below it.
                HoledRect(hole: zenith, radius: r)
                    .fill(Color.tertiary, style: FillStyle(eoFill: true))
                    .opacity(band.opacity)
                
//                Circle()
//                    .stroke(
//                        style: .init(
//                            lineWidth: 0.8,
//                            lineCap: .round,
//                            lineJoin: .round,
//                            dash: [10, 10]
//                        )
//                    )
//                    .frame(width: r*2, height: r*2)
//                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// A canvas-filling rectangle with a circular hole. Fill it with
    /// `FillStyle(eoFill: true)` so the circle punches through.
    private struct HoledRect: Shape {
        var hole:   CGPoint
        var radius: CGFloat
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.addRect(rect)                                   // whole-canvas cover
            p.addEllipse(in: CGRect(x: hole.x - radius,       // the hole
                                    y: hole.y - radius,
                                    width:  radius * 2,
                                    height: radius * 2))
            return p
        }
    }

    /// Stereographic screen radius (projection units) of the
    /// constant-`altitude` circle.
    private static func projectionRadius(_ altitude: Angle) -> CGFloat {
        let a = altitude.radians
        return CGFloat(2 * cos(a) / (1 + sin(a)))
    }
}

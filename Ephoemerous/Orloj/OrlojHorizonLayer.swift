import SwiftUI

// Fixed tympan: the horizon circle. Centre is offset by cot(φ) along the
// meridian (opposite the zenith); radius is 1/sin(φ). Clipped to the
// Tropic of Cancer — the lower part is off the visible astrolabe.
struct OrlojHorizonLayer: View {
    let geometry: EOrlojGeometry

    var body: some View {
        Canvas { ctx, _ in
            ctx.clip(to: circlePath(centre: geometry.center,
                                    radius: geometry.tropicCancerRadius))
            ctx.stroke(circlePath(centre: geometry.horizonCentre,
                                   radius: geometry.horizonRadius),
                       with: .color(.primary), lineWidth: 1.5)
        }
    }
}

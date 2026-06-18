import SwiftUI
import LoreKit

// MARK: - CelestialGestureCoordinator + Inertia
// Pan-release fling: clamp the launch speed and hand it to a `FlingInertia`
// (LoreKit's exponential-decay momentum model). `EAppState.advanceCanvasClock`
// consumes the transition each frame and stops once it settles or hits an edge.
extension CelestialGestureCoordinator {

    func startInertiaIfFlung(state: EAppState, velocity: CGSize) {
        let speed = hypot(velocity.width, velocity.height)
        guard speed > minimumFlingSpeed else { return }
        let damp = min(1, maximumFlingSpeed / speed)   // clamp wild flicks
        let now  = Date().timeIntervalSinceReferenceDate
        state._inertiaTransition = FlingInertia(
            velX:            velocity.height * damp,   // offset.x follows vertical
            velY:            velocity.width  * damp,   // offset.y follows horizontal
            startTime:       now,
            lastEmittedTime: now,
            decayRate:       flingDecayRate            // lower than LoreKit's default → longer glide
        )
    }

    func stopInertia(state: EAppState) {
        if state._inertiaTransition != nil { state._inertiaTransition = nil }
    }
}

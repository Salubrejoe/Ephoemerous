import Foundation

// MARK: - FlingInertia
// Momentum glide after a fling. Velocity decays exponentially:
//
//   v(t) = v0 · e^(−k·t)
//
// Each `advance(to:)` call returns the *exact* integral of v over the slice
// `[lastEmittedTime, time]`, so the distance travelled is identical regardless
// of frame rate. Total travel from launch to rest ≈ |v0| / k.
//
// Pure value math, no SwiftUI / UIKit / app-state coupling — store one of
// these in your view-model and call `advance(to:)` each frame to obtain the
// delta to apply this slice, plus a `finished` flag for when to release it.
public struct FlingInertia: Sendable {

    /// Launch velocity along the x axis, points/second.
    public let velX:      Double
    /// Launch velocity along the y axis, points/second.
    public let velY:      Double
    /// Reference-date timestamp at which the fling was released.
    public let startTime: Double
    /// Reference-date timestamp of the most recent `advance(to:)` slice.
    /// Mutates as the inertia is consumed.
    public var lastEmittedTime: Double

    /// Decay rate (1/s). Higher = shorter, snappier glide. Total travel ≈ |v0| / k.
    public let decayRate:         Double
    /// Stop once speed has fallen to this fraction of the launch speed.
    public let stopSpeedFraction: Double

    public init(velX: Double,
                velY: Double,
                startTime: Double,
                lastEmittedTime: Double,
                decayRate: Double = 80,
                stopSpeedFraction: Double = 0.02) {
        self.velX              = velX
        self.velY              = velY
        self.startTime         = startTime
        self.lastEmittedTime   = lastEmittedTime
        self.decayRate         = decayRate
        self.stopSpeedFraction = stopSpeedFraction
    }

    /// Returns the offset delta to apply for the slice
    /// `[lastEmittedTime, time]` and whether the glide has settled.
    /// `advance` is mutating: it remembers how far it has already emitted.
    public mutating func advance(to time: Double)
        -> (dx: Double, dy: Double, isFinished: Bool) {

        let k  = decayRate
        let t0 = max(0, lastEmittedTime - startTime)
        let t1 = max(t0, time           - startTime)
        // ∫ v0·e^(−k·t) dt  from t0 to t1  =  (v0/k)·(e^(−k·t0) − e^(−k·t1))
        let span = (exp(-k * t0) - exp(-k * t1)) / k
        lastEmittedTime = time
        let finished = exp(-k * t1) < stopSpeedFraction
        return (velX * span, velY * span, finished)
    }
}

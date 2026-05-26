import Foundation

// MARK: - Double math
// Tiny utility kit on `Double` that's annoying to keep re-typing.
public extension Double {

    static var twoPi:  Double { .pi * 2     }
    static var piHalf: Double { .pi * 0.5   }

    /// Clamp into a closed range — `(-5.0).clamped(to: 0...10) == 0`.
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    /// iOS UIScrollView-style rubber-band damping.
    ///
    /// Within `[-limit, +limit]` the value is returned unchanged. Past the
    /// limit each extra point of pull yields progressively less travel,
    /// asymptotic to `limit + dim` — exactly the curve a UIScrollView uses
    /// when bouncing off its content edge. `c` is the dimensionless damping
    /// constant Apple's implementation hard-codes at 0.55.
    ///
    /// Use this for any "rubber band against a hard edge" interaction:
    /// pan past a viewport limit, pinch past a scale ceiling, etc.
    func rubberBanded(limit: Double, dim: Double, c: Double = 0.55) -> Double {
        let a = abs(self)
        guard a > limit, dim > 0 else { return self }
        let over   = a - limit
        let damped = (1 - 1 / (over * c / dim + 1)) * dim
        return (self < 0 ? -1.0 : 1.0) * (limit + damped)
    }
}

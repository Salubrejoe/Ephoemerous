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
}

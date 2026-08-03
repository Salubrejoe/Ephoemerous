import SwiftUI

// MARK: - CanvasSchedule
// A `TimelineSchedule` with two states:
//   • Animating → emit a tick every 1/60s so an animation interpolates.
//   • Idle → emit ONE tick at `start`, then park at `.distantFuture` so the
//     timeline effectively stops doing work until `isAnimating` flips true
//     again (which re-evaluates the view body and hands TimelineView a fresh
//     `CanvasSchedule(isAnimating: true)`).
//
// The SkyLab clock uses it to tick only while an app transition (Here/Now,
// date rotation) or compass heading is live, and freeze at rest. Extracted
// to live from the now-deprecated CelestialCanva so the rendering folder can
// be removed without taking this with it.
struct CanvasSchedule: TimelineSchedule {
    let isAnimating: Bool

    func entries(from start: Date, mode: Mode) -> Entries {
        Entries(isAnimating: isAnimating, start: start)
    }

    struct Entries: Sequence, IteratorProtocol {
        let isAnimating: Bool
        var next_date: Date
        init(isAnimating: Bool, start: Date) {
            self.isAnimating = isAnimating
            self.next_date   = start
        }
        mutating func next() -> Date? {
            let current = next_date
            if isAnimating {
                next_date = current.addingTimeInterval(1.0 / 60)
                return current
            }
            // Idle: one tick at start, then park forever.
            if current == .distantFuture {
                return .distantFuture
            }
            next_date = .distantFuture
            return current
        }
    }
}

// DEPRECATED — kept for reference only. `EChromeTransition` drove
// the chrome's scale + fade during a Clock↔Travel toggle; both
// toggle and chrome concept are gone. Wrapped in `#if false` so the
// file is preserved as source-of-truth-for-history without being
// part of the build.

#if false
import SwiftUI

// MARK: - EChromeTransition
// Drives the watch-chrome (WatchBackgroundLayer + ClipAndHoursLayer)
// scale-and-fade during a mode toggle:
//
//   • Clock → Travel:  direction = .expanding
//       opacity 1 → 0, radiusScale 1 → maxRadiusScale.
//       The chrome "blows out" past the screen as it disappears.
//
//   • Travel → Clock:  direction = .collapsing
//       opacity 0 → 1, radiusScale maxRadiusScale → 1.
//       The chrome shrinks in from a huge ring as it reappears.
//
// The transition is started by `toggleAppMode` and cleared explicitly by
// the same code path that ends the toggle (the slerp's `onCompletion`
// for forward, an `asyncAfter` for reverse). The getters do NOT
// self-clear, so there's no race against those explicit clears.
struct EChromeTransition {

    enum Direction { case expanding, collapsing }

    let direction      : Direction
    let startTime      : Double
    let duration       : Double
    let maxRadiusScale : Double

    private func progress(at time: Double) -> Double {
        max(0, min(1, (time - startTime) / duration))
    }

    func opacity(at time: Double) -> Double {
        let p = smoothstep(progress(at: time))
        switch direction {
        case .expanding:  return 1 - p
        case .collapsing: return p
        }
    }

    func radiusScale(at time: Double) -> Double {
        let p = smoothstep(progress(at: time))
        switch direction {
        case .expanding:  return 1 + p * (maxRadiusScale - 1)
        case .collapsing: return maxRadiusScale - p * (maxRadiusScale - 1)
        }
    }

    func isFinished(at time: Double) -> Bool {
        time >= startTime + duration
    }

    private func smoothstep(_ x: Double) -> Double {
        let t = max(0, min(1, x))
        return t * t * (3 - 2 * t)
    }
}

// MARK: - EAppState + chrome state
//
// The old `chromeOpacity` / `chromeRadiusScale` getters belonged to
// the watch-chrome fade animation that fired during a Clock↔Travel
// toggle. Both appMode and the toggle are gone, so the getters had
// no readers left (chromeOpacity never had a live one; chromeRadius-
// Scale was used by EArtist+Chrome to size the disc and now folds
// down to a constant 1). The `EChromeTransition` struct above also
// only existed to drive those getters; both struct and file land in
// DeprecationStation in a follow-up commit.
#endif

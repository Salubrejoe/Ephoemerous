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
extension EAppState {

    /// Chrome alpha for the current frame. 1 = fully visible, 0 = hidden.
    /// While a chrome transition is in flight it's driven by the
    /// transition's curve; otherwise it falls back to the appMode
    /// (clock = 1, travel = 0).
    var chromeOpacity: Double {
        if let t = _chromeTransition {
            return t.opacity(at: animationTime)
        }
        return appMode == .clock ? 1 : 0
    }

    /// Multiplier on every chrome radius (disc, hours ring, etc.).
    /// 1 at rest; > 1 while the chrome is mid-expand/collapse.
    var chromeRadiusScale: Double {
        if let t = _chromeTransition {
            return t.radiusScale(at: animationTime)
        }
        return 1
    }
}

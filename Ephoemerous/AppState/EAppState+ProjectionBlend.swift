import SwiftUI

// MARK: - EProjectionTransition
// The clock↔travel transition. Drives two things in parallel:
//   • An origin slerp (managed by `_originTransition`) from the observer's
//     real location to the celestial north pole (or back).
//   • A cross-fade between the clock-layer group and the travel-layer
//     group, with its window pinned to whichever end of the slerp NP sits.
//
// At observer = NP the userLocation projection (with -Q dropped, see
// `EProjection.project`) coincides exactly with the northSouth projection,
// so the layer swap is geometrically seamless at the bridge moment.
struct EProjectionTransition {

    enum Direction { case toTravel, toClock }

    let startTime : Double
    let duration  : Double
    let direction : Direction

    private func progress(at time: Double) -> Double {
        max(0, min(1, (time - startTime) / duration))
    }

    /// Travel-layer opacity: 0 = clock visible, 1 = travel visible. The
    /// 40 %-wide cross-fade window is parked at whichever end of the slerp
    /// the observer reaches NP — the end for Clock→Travel, the start for
    /// Travel→Clock.
    func travelOpacity(at time: Double) -> Double {
        let p = progress(at: time)
        switch direction {
        case .toTravel: return smoothstep((p - 0.6) / 0.4)   // bridge at p=1
        case .toClock:  return 1 - smoothstep(p / 0.4)       // bridge at p=0
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

// MARK: - EAppState + mode transition
extension EAppState {

    /// True while the cross-fade window is in flight. EProjection drops the
    /// -Q from the userLocation branch when this is true, so UL and NS
    /// coincide at the moment the observer reaches NP.
    var isModeTransitioning: Bool {
        guard let t = _projectionTransition else { return false }
        return !t.isFinished(at: animationTime)
    }

    /// Travel-layer opacity for the current frame. Self-clears the
    /// transition once it finishes — same pattern as the old envelope.
    var renderedTravelOpacity: Double {
        guard let t = _projectionTransition else {
            return appMode == .travel ? 1 : 0
        }
        if t.isFinished(at: animationTime) {
            _projectionTransition = nil
            return appMode == .travel ? 1 : 0
        }
        return t.travelOpacity(at: animationTime)
    }

    /// Clock-layer opacity is the complement; reading this also drives
    /// the self-clear above.
    var renderedClockOpacity: Double {
        1 - renderedTravelOpacity
    }

    /// Start the cross-fade for a given direction. The accompanying origin
    /// slerp is triggered by `toggleAppMode` so the two stay synchronised.
    func beginModeTransition(direction: EProjectionTransition.Direction,
                             duration: Double = AstroConstants.modeTransitionDuration) {
        _projectionTransition = EProjectionTransition(
            startTime: Date.now.timeIntervalSinceReferenceDate,
            duration:  duration,
            direction: direction
        )
    }
}

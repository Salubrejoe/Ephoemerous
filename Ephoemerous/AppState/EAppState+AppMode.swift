import SwiftUI
import UIKit

// MARK: - EAppMode
// The two top-level experiences: the watch-face clock and free-roam travel.
enum EAppMode {
    case clock, travel

    mutating func toggle() {
        self = self == .clock ? .travel : .clock
    }
}

// MARK: - EAppState + AppMode
extension EAppState {

    /// Clock↔Travel via a synchronised origin slerp + cross-fade.
    ///
    ///   Clock → Travel: snapshot the current origin, slerp it to the
    ///     celestial north pole; the cross-fade fades the clock layers out
    ///     and the travel layers in at the END of the slerp (the bridge
    ///     moment when UL with -Q dropped == NS).
    ///   Travel → Clock: slerp the origin from NP back to the snapshotted
    ///     clock origin; the cross-fade swaps groups at the START of the
    ///     slerp (same bridge moment, mirrored timing).
    ///
    /// `appMode` flips at the END of each transition so the
    /// `renderedClockOpacity` / `renderedTravelOpacity` fallback resolves
    /// to the right group once the transition self-clears.
    func toggleAppMode() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        let dur = AstroConstants.modeTransitionDuration

        switch appMode {
        case .clock:
            _savedClockOrigin = origin
            animateOrigin(to:  .degrees(90),
                          lon: origin.longitude,
                          duration: dur)
            beginModeTransition(direction: .toTravel, duration: dur)

        case .travel:
            let restore = _savedClockOrigin ?? origin
            animateOrigin(to:  restore.latitude,
                          lon: restore.longitude,
                          duration: dur)
            beginModeTransition(direction: .toClock, duration: dur)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dur) { [weak self] in
            guard let self else { return }
            self.appMode.toggle()
            self.projectionMode = .drag
        }
    }
}

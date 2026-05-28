// DEPRECATED — kept for reference only. `EAppMode` and the
// Clock↔Travel toggle are gone; travel-mode behaviour wins
// everywhere. References to `appMode`, `_chromeTransition`,
// `_savedClockOrigin`, `EChromeTransition` no longer exist on
// `EAppState`, so this file is wrapped in `#if false` to keep it
// out of the build.

#if false
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

    /// Clock↔Travel transition.
    ///
    ///   Clock → Travel:
    ///     1. Snapshot the real origin (so a future "centre on me" still
    ///        has it).
    ///     2. Slerp origin to lat 90°. EarthGrid and Horizon morph along
    ///        with it; everything else stays put (NS).
    ///     3. In the same dispatch as the final `setOrigin(90°,…)`, flip
    ///        `appMode = .travel` via the slerp's `onCompletion`. Chrome
    ///        self-gates off and the six NS layers switch to UL — at
    ///        lat 90° the two projections coincide, so the swap is
    ///        invisible. No race, no phase flash.
    ///
    ///   Travel → Clock:
    ///     Flip `appMode = .clock` immediately. Chrome reappears and the
    ///     six layers swap back to NS — origin is wherever the user left
    ///     it in travel (today: NP; later: wherever they explored to),
    ///     so the swap is invisible at NP and harmless elsewhere because
    ///     NS layers don't read origin. We do NOT auto-restore the saved
    ///     clock origin — the user's view in travel sticks.
    ///
    /// A second tap during an in-flight slerp is ignored, so the user
    /// can't break the state by mashing the button.
    func toggleAppMode() {
        guard _originTransition == nil,
              _chromeTransition == nil else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        let dur          = AstroConstants.modeTransitionDuration
        let chromeMaxR   = AstroConstants.chromeMaxRadiusScale
        let now          = Date.now.timeIntervalSinceReferenceDate

        switch appMode {
        case .clock:
            _savedClockOrigin = origin
            _chromeTransition = EChromeTransition(
                direction:      .expanding,
                startTime:      now,
                duration:       dur,
                maxRadiusScale: chromeMaxR
            )
            animateOrigin(to:       .degrees(90),
                          lon:      origin.longitude,
                          duration: dur) { [weak self] in
                guard let self else { return }
                self.appMode           = .travel
                self._chromeTransition = nil
            }

        case .travel:
            appMode           = .clock
            _chromeTransition = EChromeTransition(
                direction:      .collapsing,
                startTime:      now,
                duration:       dur,
                maxRadiusScale: chromeMaxR
            )
            // Small buffer past the natural endpoint so the clear can't
            // race ahead of `animationTime` reaching `now + dur`.
            DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.05) { [weak self] in
                self?._chromeTransition = nil
            }
        }
    }
}
#endif

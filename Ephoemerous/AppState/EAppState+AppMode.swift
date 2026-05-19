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

    /// Switch between clock and travel via a blur+opacity defocus: the
    /// composition blurs/dims out, the mode flips at the envelope peak
    /// (hard cut hidden), then it sharpens back. Ends on `.drag` (the
    /// sensible default in either mode).
    func toggleAppMode() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        let dur = AstroConstants.modeTransitionDuration
        beginModeTransition(duration: dur)

        // Flip at the envelope peak so the swap is masked by max blur.
        DispatchQueue.main.asyncAfter(deadline: .now() + dur / 2) { [weak self] in
            guard let self else { return }
            self.appMode.toggle()
            self.projectionMode = .drag
        }
    }
}

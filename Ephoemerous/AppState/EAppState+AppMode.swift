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

    /// Switch between clock and travel. The projection is coupled while the
    /// sky settles, the mode flips on a brief animated delay, and the
    /// projection ends on `.drag` (the sensible default in either mode).
    ///
    /// Bumping the coupled-restore generation cancels any pending restore
    /// from another feature so it can't fire mid-toggle and fight us.
    func toggleAppMode() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        _coupledRestoreGeneration &+= 1
        let thisGeneration = _coupledRestoreGeneration
        _coupledRestoreMode = nil
        projectionMode      = .coupled

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self,
                  self._coupledRestoreGeneration == thisGeneration else { return }
            // Kick the cross-fade BEFORE flipping appMode: animateProjection-
            // Blend reads the current blend as its start, so this must run
            // while appMode is still the old value (target = the new one).
            let blendTarget: Double = self.appMode == .clock ? 1 : 0
            self.animateProjectionBlend(to: blendTarget)
            withAnimation { self.appMode.toggle() }
            self.projectionMode = .drag
        }
    }
}

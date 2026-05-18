import SwiftUI

// MARK: - ProjectionMode
// How a one-finger drag is interpreted on the celestial canvas.
enum ProjectionMode: String, CaseIterable {
    case drag    = "drag"      // pan the viewport
    case coupled = "coupled"   // move the observer, axis-locked
    case origin  = "origin"    // move the observer freely (travel only)

    var symbol: String {
        switch self {
        case .drag:    "arrow.up.and.down.and.arrow.left.and.right"
        case .coupled: "arcade.stick.and.arrow.up.and.arrow.down"
        case .origin:  "figure.walk.motion"
        }
    }

    var color: Color {
        switch self {
        case .drag:    .primary
        case .coupled: .baseOrange
        case .origin:  .baseCoral
        }
    }
}

// MARK: - EAppState + ProjectionMode
extension EAppState {

    /// The modes the user may pick in the current app mode.
    /// `.origin` only makes sense in travel mode.
    var selectableProjectionModes: [ProjectionMode] {
        appMode == .travel ? ProjectionMode.allCases : [.drag, .coupled]
    }

    /// Run an animated origin/date change with the projection temporarily
    /// forced to `.coupled`, then restore the mode the user actually chose.
    ///
    /// A generation token guarantees that overlapping calls (e.g. change the
    /// date, then immediately tap "go to my location") can neither strand the
    /// app in `.coupled` nor restore a stale mode: only the latest scheduled
    /// restore runs, and the *real* mode is captured once on first entry.
    func useCoupledProjectionTemporarily(
        for     duration:       Double,
        perform animatedChange: () -> Void
    ) {
        if _coupledRestoreMode == nil {
            _coupledRestoreMode = projectionMode
        }
        projectionMode = .coupled
        animatedChange()

        _coupledRestoreGeneration &+= 1
        let thisGeneration = _coupledRestoreGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self,
                  self._coupledRestoreGeneration == thisGeneration else { return }
            if let restored = self._coupledRestoreMode {
                self.projectionMode = restored
            }
            self._coupledRestoreMode = nil
        }
    }
}

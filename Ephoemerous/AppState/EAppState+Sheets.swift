import Foundation

// MARK: - EAppState + Sheets
// Convenience helpers for sheet / modal presentation state.
// The boolean flags themselves live in EAppState.swift so @Observable
// can track them; this extension just adds coordinated operations.
extension EAppState {

    /// Dismiss all sheets at once — useful when switching app modes
    /// or navigating to a context where overlapping sheets would be confusing.
    func closeAllSheets() {
        showSunInfo         = false
        showMoonInfo        = false
        showStarList        = false
        showStarView        = false
    }

    // MARK: Focus + present
    // Tapping a body on the canvas does the same three things every time:
    // clear other sheets, track the body, present its info sheet. These
    // bundle that so ObjectsTrackingOverlay stays declarative.

    func presentSunInfo() {
        closeAllSheets()
        applySunTracking()
        showSunInfo = true
    }

    func presentMoonInfo() {
        closeAllSheets()
        applyMoonTracking()
        showMoonInfo = true
    }

    func presentStarInfo(_ star: EStar) {
        closeAllSheets()
        applyStarTracking(star)
        currentlyDisplayedStar = star
        showStarView = true
    }
}

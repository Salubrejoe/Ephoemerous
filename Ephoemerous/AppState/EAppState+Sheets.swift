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
}

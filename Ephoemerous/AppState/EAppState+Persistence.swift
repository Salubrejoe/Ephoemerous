import Foundation

// MARK: - EAppState + Persistence
// The single boundary to iCloud KVS. Views never touch ECloudSync
// directly; they call the named functions here. Layer-visibility
// persistence is gone (every layer is always on now); only the
// magnitude filter slider syncs.
extension EAppState {

    /// Push the current magnitude filter to iCloud. Called from
    /// MainView's `.onChange(of: magnitudeFilter)`.
    func persistMagnitudeFilter() {
        ECloudSync.shared.saveMagnitudeFilter(magnitudeFilter)
    }

    func startCloudSync() {
        ECloudSync.shared.start(appState: self)
    }
}

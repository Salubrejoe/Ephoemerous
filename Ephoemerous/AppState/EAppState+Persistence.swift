import Foundation

// MARK: - EAppState + Persistence
// The single boundary to iCloud KVS. Views never touch ECloudSync
// directly. The two persisted pieces (favourites, magnitude filter)
// both push via their property `didSet` — so the only thing this
// extension needs to expose is the bootstrap call that wires up
// the initial load + iCloud-notification subscription.
extension EAppState {

    func startCloudSync() {
        ECloudSync.shared.start(appState: self)
    }
}

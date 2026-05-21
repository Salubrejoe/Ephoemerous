import Foundation

// MARK: - EAppState + Persistence
// The single boundary to CloudKit. Views never touch ECloudSync directly;
// they observe `layerVisibilitySignature` and call the named functions here.
extension EAppState {

    /// One integer that changes whenever any layer-visibility toggle flips,
    /// so a view can watch all flags with a single `.onChange`.
    var layerVisibilitySignature: Int {
        (showEquatorTropics       ? 1   : 0) |
        (showEcliptic             ? 2   : 0) |
        (showNSMeridians          ? 4   : 0) |
        (showULMeridians          ? 8   : 0) |
        (showHorizon              ? 16  : 0) |
        (showStars                ? 32  : 0) |
        (showPlanets              ? 64  : 0) |
        (showSelectedStars        ? 128 : 0) |
        (showConstellationLines   ? 256 : 0) |
        (showConstellationNames   ? 512 : 0)
    }

    func persistLayerVisibility() {
        ECloudSync.shared.saveLayerVisibility(self)
    }

    func startCloudSync() {
        ECloudSync.shared.start(appState: self)
    }
}

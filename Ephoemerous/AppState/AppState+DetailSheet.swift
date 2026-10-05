import SwiftUI

// MARK: - AppState + DetailSheet
extension AppState {

    /// How far the detail sheet is pulled up, 0…1 — 0 at its resting third
    /// (and below), 1 at full screen. Read live off the sheet's top edge
    /// (`bottomSheetTop`, published every frame of a drag), so whatever
    /// follows it — the place header's title, the sheet's night backdrop —
    /// moves WITH the finger rather than switching at a detent.
    var detailSheetExpansion: CGFloat {
        guard let top = bottomSheetTop else { return 0 }
        let h      = Self.screenHeight
        let rest   = h * 2 / 3                  // the resting third
        let raised = h * 0.08                   // ≈ the large detent's top
        return min(1, max(0, (rest - top) / (rest - raised)))
    }

    private static var screenHeight: CGFloat {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?
            .effectiveGeometry.coordinateSpace.bounds.height ?? 874
    }
}

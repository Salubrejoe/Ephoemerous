import SwiftUI

// MARK: - Bottom-sheet detent tracking
// SwiftUI's `presentationDetents(selection:)` is DISCRETE — it reports the
// detent the sheet SETTLED on, after the drag. To lift the floating chrome
// in sync and to morph a title continuously, we need the LIVE height while
// dragging. The reliable source is the sheet content's own top edge:
// `onGeometryChange` on it fires every frame the sheet moves.
//
// Attach `.tracksBottomSheet()` to a sheet's root content; it publishes the
// top edge to `EAppState.bottomSheetTop` and clears it on dismiss.
private struct BottomSheetTracker: ViewModifier {
    @Environment(EAppState.self) private var app

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY
            } action: { top in
                app.bottomSheetTop = top
            }
            .onDisappear { app.bottomSheetTop = nil }
    }
}

extension View {
    /// Publish this sheet's live top-edge Y (global) to
    /// `EAppState.bottomSheetTop` for every frame of the drag. See
    /// `BottomSheetTracker`.
    func tracksBottomSheet() -> some View { modifier(BottomSheetTracker()) }
}

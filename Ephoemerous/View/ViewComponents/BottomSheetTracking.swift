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

    /// Publisher identity. During a sheet SWAP (search → detail) the two
    /// trackers overlap: the incoming sheet publishes while the outgoing
    /// one is still dismissing, and the outgoing `onDisappear` fires LAST.
    /// An unconditional nil-clear there would erase the incoming sheet's
    /// value and strand the chrome at rest — so a tracker only clears the
    /// slot if it is still the one that last wrote it.
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY
            } action: { top in
                app.bottomSheetTop    = top
                app._bottomSheetOwner = id
            }
            .onDisappear {
                guard app._bottomSheetOwner == id else { return }
                app.bottomSheetTop    = nil
                app._bottomSheetOwner = nil
            }
    }
}

extension View {
    /// Publish this sheet's live top-edge Y (global) to
    /// `EAppState.bottomSheetTop` for every frame of the drag. See
    /// `BottomSheetTracker`.
    func tracksBottomSheet() -> some View { modifier(BottomSheetTracker()) }
}

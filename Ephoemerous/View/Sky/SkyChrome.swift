import SwiftUI

// MARK: - SkyChrome
// The floating controls that sit over the sky: the context capsule at the
// top, the camera-family capsule, and the transient compass rose.
//
// Chrome grammar (current-Maps layout): the context capsule ALONE at
// top-centre; the camera capsule bottom-trailing just above the search bar,
// in thumb territory; the compass rose on the OPPOSITE edge so it can appear
// and vanish without nudging the capsule. The sky's centre stays sacred.
//
// A modifier rather than lines in `MainView.body` because it is a
// self-contained layer with its own placement rules — and because the body
// had grown to 458 lines, of which this was a solid slice.
struct SkyChrome: ViewModifier {

    @Environment(AppState.self) private var app
    /// Visible screen size, for the sheet-riding lift below.
    let viewSize: CGSize

    /// iPad moves the camera cluster to the top-trailing corner — the wide
    /// canvas leaves the bottom-trailing slot marooned mid-air above the
    /// full-width search sheet.
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// The floating panel's inset from the screen edge — chrome on the
    /// same edge lines up with it. Mirrors `FloatingPanel.margin`.
    private static let padMargin: CGFloat = 20

    /// Bottom padding so a floating control rides the frontmost sheet's top
    /// edge (published live in `app.bottomSheetTop`), a `gap` above it.
    /// Clamped at `rest` so chrome never dips below its resting home — it
    /// sits above the bar detent and RISES only as the sheet expands past
    /// it, exactly like Apple Maps' controls.
    private func sheetLift(gap: CGFloat, rest: CGFloat) -> CGFloat {
        guard let top = app.bottomSheetTop, viewSize.height > 0 else { return rest }
        return max(rest, viewSize.height - top + gap)
    }

    func body(content: Content) -> some View {
        content
        // Production toolbar — Here / Now reset chips + location / date
        // pills. It acts on the shared AppState the SkyLab camera reads,
        // so the sky follows; the clock above plays the transitions.
        // Chrome grammar (current-Maps layout): context capsule ALONE at
        // top-centre; the camera-family capsule (flip + compass mode)
        // bottom-trailing just above the search bar — thumb territory; the
        // transient compass rose on the OPPOSITE edge so it can appear /
        // vanish without nudging the capsule. The sky's centre stays sacred.
        .overlay(alignment: isPad ? .topLeading : .top) {
            // iPad: top-LEADING, on the panel's own margin so the two read
            // as one column of chrome down that edge — and bigger, because
            // the phone's 40pt bar is lost on a 13" canvas.
            MainToolbar(barHeight: isPad ? 52 : 40)
                .padding(.horizontal, isPad ? Self.padMargin : 16)
                .padding(.top,        64)
        }
        .overlay(alignment: isPad ? .topTrailing : .bottomTrailing) {
            // Hidden while a scene editor is up — camera-mode toggles are
            // noise mid-picking, and the floating date crown owns the
            // bottom stage.
            if !app.isShowingDatePicker && !app.isShowingLocationPicker {
                let lift = sheetLift(gap: 12, rest: 114)
                CameraClusterCapsule()
                    .padding(.trailing, 16)
                    // iPad: top-trailing, level with the context capsule
                    // (same 64pt top inset as MainToolbar). iPhone: rides
                    // the frontmost sheet's top edge — rests above the
                    // search bar (114) and rises 1:1 as the sheet expands.
                    // ▼ TWEAK the rest / gap here ▼
                    .padding(.top,    isPad ? 64 : 0)
                    .padding(.bottom, isPad ? 0  : lift)
                    // A sheet PRESENTING publishes its top edge once, not
                    // per-frame like a drag — animate the lift so the pill
                    // glides to meet it instead of snapping. Drag frames
                    // just retarget the spring; the pill trails by a hair.
                    .animation(.snappy(duration: 0.28), value: lift)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottomLeading) {
            // Compass rose — self-hides when the sky is upright; tap
            // springs back to North.
            // Rest clears the floating panel (74 + its 20 margin) with air
            // to spare on iPad; the phone keeps its sheet-relative 124.
            let roseLift = sheetLift(gap: 22, rest: isPad ? 150 : 124)
            CompassButton(faceSize: isPad ? 58 : 44)
                // Same margin as the floating panel below it, so the rose
                // sits on the card's leading edge rather than 4pt inside it.
                .padding(.leading, isPad ? Self.padMargin : 16)
                .padding(.bottom, roseLift)
                // Same glide as the camera cluster — the bottom chrome
                // moves as one when a sheet presents.
                .animation(.snappy(duration: 0.28), value: roseLift)
        }
    }
}

#if DEBUG
#Preview("Chrome over the sky") {
    Artist.shared.canvasBackground
        .modifier(SkyChrome(viewSize: CGSize(width: 390, height: 844)))
        .environment(AppState())
}
#endif

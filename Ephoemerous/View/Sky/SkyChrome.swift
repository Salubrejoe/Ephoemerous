import SwiftUI

// MARK: - SkyChrome
// The floating controls that sit over the sky: the context capsule at the
// top, the camera-family capsule, and the transient compass rose.
//
// Chrome grammar (current-Maps layout): the context capsule ALONE at
// top-centre (regular width: bottom-trailing, level with the floating
// panel); the camera capsule bottom-trailing just above the search bar,
// in thumb territory; the compass rose on the OPPOSITE edge so it can appear
// and vanish without nudging the capsule. The sky's centre stays sacred.
//
// iPhone Duo, where the system keeps a side rail (outer display, inner
// display in landscape): the camera cluster and the rose move INTO that
// rail as system toolbar items — see `SkyRail` — and their floating
// versions stand down. The Here / Now capsule stays a capsule (words stay
// horizontal), centred over the sky beside the rail. The inner display in
// portrait centres it over the whole screen, clear of the status bar.
//
// A modifier rather than lines in `MainView.body` because it is a
// self-contained layer with its own placement rules — and because the body
// had grown to 458 lines, of which this was a solid slice.
struct SkyChrome: ViewModifier {

    @Environment(AppState.self) private var app
    /// Visible screen size, for the sheet-riding lift below.
    let viewSize: CGSize

    /// Wide window — the floating panel replaces the bottom sheet (same key
    /// as MainView), the pill drops to the panel's baseline and the camera
    /// cluster moves to the top-trailing corner. Keyed on the size class,
    /// NOT the idiom: iPhone Duo's inner display is an iPhone with a
    /// regular width, and a narrow Stage Manager / Slide Over iPad window
    /// is compact and gets the phone's sheet.
    @Environment(\.horizontalSizeClass) private var hSize
    private var isRegular: Bool { hSize == .regular }

    /// iPhone Duo's side rail is up — the camera chrome lives in it instead
    /// of floating over the sky. False everywhere else, including the Duo's
    /// inner display in portrait, which keeps horizontal bars. Read by
    /// MainView, which also needs it to fit the sky.
    let hasRail: Bool

    /// iPhone Duo open — flat or folded — where the rail runs down the
    /// trailing edge of a regular-width screen.
    private var openDuo: Bool { isRegular && hasRail }

    /// iPhone Duo's inner display in portrait: the hinge runs across the
    /// screen and the status bar's clock holds the top-trailing corner, so
    /// the capsule centres over the whole screen instead.
    private var hingeAcross: Bool { isRegular && app.skyHingeAcross != nil }

    /// Top-centre on the phone, top-trailing in regular width — the iPad,
    /// and the open Duo, which takes the iPad's layout (padded clear of
    /// its rail) — except across the Duo's hinge, top-centre again.
    private var toolbarAlignment: Alignment {
        isRegular && !hingeAcross ? .topTrailing : .top
    }

    /// The Here / Now capsule's bottom edge in regular width — the floating
    /// panel stops below it where the two would meet (see MainView).
    static var padToolbarBottom: CGFloat { padToolbarTop + padBarHeight }

    /// The rail stays on the hardware's right in every language.
    @Environment(\.layoutDirection) private var layoutDirection
    private var railEdge: Edge.Set { layoutDirection == .rightToLeft ? .leading : .trailing }

    /// The floating panel's inset from the screen edge — chrome on the
    /// same edge lines up with it. Mirrors `FloatingPanel.margin`.
    private static let padMargin: CGFloat = 16
    /// The iPad's Here / Now capsule height. ▼ TWEAK ▼
    private static let padBarHeight: CGFloat = 52
    /// Regular width: the camera cluster sits as far from the bottom edge
    /// as from the trailing one — the margin the panel keeps on its two
    /// edges — so the bottom row reads as one even inset.
    private static var padClusterBottom: CGFloat { padMargin }
    /// Regular width: the Here / Now capsule's drop from the top edge,
    /// clear of the status bar. ▼ TWEAK ▼
    private static var padToolbarTop: CGFloat { 40 }
    /// Compact: the capsule's drop from the top edge. ▼ TWEAK ▼
    private static var phoneToolbarTop: CGFloat { 64 }

    /// The capsule's drop from the top. On iPhone Duo's outer display it
    /// lines up with the front camera — its centre on the camera's — so the
    /// top row reads as one band with the camera and the rail.
    private func toolbarTop(barHeight: CGFloat) -> CGFloat {
        if isRegular { return Self.padToolbarTop }
        if hasRail, let cameraMidY = app.skyCameraMidY {
            return max(0, cameraMidY - barHeight / 2)
        }
        return Self.phoneToolbarTop
    }

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
        .overlay(alignment: toolbarAlignment) {
            // Regular width: top-TRAILING — bigger, because the phone's
            // 40pt bar is lost on a 13" canvas. The camera cluster takes
            // the bottom-trailing corner, in thumb territory.
            // The Duo's rail is padded off first, so the capsule centres
            // over the sky beside it (closed) or sits just left of it
            // (open), never under it.
            let barHeight: CGFloat = isRegular ? Self.padBarHeight : 40
            MainToolbar(barHeight: barHeight)
                .padding(.horizontal, isRegular ? Self.padMargin : 16)
                .padding(.top,        toolbarTop(barHeight: barHeight))
                .padding(railEdge,    hingeAcross ? 0 : app.skyRailWidth)
        }
        .overlay(alignment: .bottomTrailing) {
            // Hidden while a scene editor is up — camera-mode toggles are
            // noise mid-picking, and the floating date crown owns the
            // bottom stage.
            if !hasRail && !app.isShowingDatePicker && !app.isShowingLocationPicker {
                let lift = sheetLift(gap: 12, rest: 114)
                CameraClusterCapsule()
                    .padding(.trailing, 16)
                    // Regular: bottom-trailing on the panel's margin, the
                    // corner the capsule left for the top. Compact: rides
                    // the frontmost sheet's top edge — rests above the
                    // search bar (114) and rises 1:1 as the sheet expands.
                    // ▼ TWEAK the rest / gap here ▼
                    .padding(.bottom, isRegular ? Self.padClusterBottom : lift)
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
            // to spare in regular width; compact keeps its sheet-relative 124.
            if !hasRail {
                let roseLift = sheetLift(gap: 22, rest: isRegular ? 150 : 124)
                CompassButton(faceSize: isRegular ? 58 : 44)
                    // Same margin as the floating panel below it, so the rose
                    // sits on the card's leading edge rather than 4pt inside it.
                    .padding(.leading, isRegular ? Self.padMargin : 16)
                    .padding(.bottom, roseLift)
                    // Same glide as the camera cluster — the bottom chrome
                    // moves as one when a sheet presents.
                    .animation(.snappy(duration: 0.28), value: roseLift)
            }
        }
        // iPhone Duo: the same controls, as rail items.
        .modifier(SkyRail(isActive: hasRail, isOpen: openDuo))
        // Re-resolve the locality name whenever the rounded origin changes.
        // Here, not on the capsule, so it keeps running while the rail
        // stands in for the capsule.
        .task(id: app.localityKey) { await app.refreshLocalityAfterSettling() }
    }
}

#if DEBUG
#Preview("Chrome over the sky") {
    Artist.shared.canvasBackground
        .modifier(SkyChrome(viewSize: CGSize(width: 390, height: 844), hasRail: false))
        .environment(AppState())
}
#endif

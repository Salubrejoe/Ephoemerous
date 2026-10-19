import SwiftUI

// MARK: - SkyRail
// iPhone Duo's side rail. On the outer display — and the inner one in
// landscape — the system stacks bars down one side, under the clock and
// the Dynamic Island: the trailing edge in portrait, either in landscape.
// The sky's floating chrome moves INTO that rail as system toolbar items,
// so the system can keep it clear of the camera, share the column with
// Live Activities, overflow what won't fit and nudge it off the fold. Everywhere else this adds nothing and
// `SkyChrome` floats the usual glass.
//
// The Here / Now capsule stays a floating capsule over the sky — its
// words are the point, and words stay horizontal.
//
// Top to bottom:
//   • the camera cluster — Orloj, projection flip, compass mode
//   • the compass rose — Apple's own example of a custom view that earns a
//     place in the rail
struct SkyRail: ViewModifier {

    @Environment(AppState.self) private var app

    /// The rail is up — see `readsSideRail(into:)`.
    let isActive: Bool
    /// The place card floats in the panel (the open Duo, the closed one
    /// in landscape) rather than a sheet with a rail of its own.
    let cardInPanel: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.toolbar {
                if isActive { SkyRailItems(app: app, cardInPanel: cardInPanel) }
            }
        } else {
            content
        }
    }
}

// MARK: - SkyRailItems
@available(iOS 27.1, *)
private struct SkyRailItems: ToolbarContent {

    let app:         AppState
    let cardInPanel: Bool

    var body: some ToolbarContent {
        // Camera toggles are noise mid-picking — same rule as the
        // floating cluster. They also stand down under a place card in a
        // sheet: the card's own rail (✕, Find, share) takes the rail's foot.
        // A card in the floating panel leaves the rail alone, so they stay.
        if !app.isShowingDatePicker && !app.isShowingLocationPicker
            && (cardInPanel || app.detailDestination == nil) {
            cameraGroup
        }
        if !app.isSkyUpright {
            rose
        }
    }

    /// The camera capsule's buttons, bare — the rail's glass is their
    /// capsule now. Custom views, so they keep the flip's long-press into
    /// Look and the accent tint that says "engaged".
    private var cameraGroup: some ToolbarContent {
        // The rail's foot — thumb territory, as the floating capsule sits
        // bottom-trailing everywhere else.
        ToolbarItemGroup(placement: .bottomBar) {
            if app.canShowOrloj {
                OrlojButton(bare: true)
            }
            ProjectionFlipButton(bare: true)
            CompassModeButton(bare: true)
        }
        .axisBehavior(.verticalPreferred)
        .visibilityPriority(.high)
    }

    /// The rose keeps its own squircle glass — it's the signature — so the
    /// rail's shared background stands aside for it.
    private var rose: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            CompassButton()
        }
        .axisBehavior(.verticalPreferred)
        .sharedBackgroundVisibility(.hidden)
    }
}

// MARK: - Reading the rail
extension View {
    /// Writes whether iPhone Duo's side rail is up into `hasRail` — true
    /// when the system can lay bars vertically here, false on every other
    /// device and pose (and before iOS 27.1).
    func readsSideRail(into hasRail: Binding<Bool>) -> some View {
        readsSideRail { hasRail.wrappedValue = $0 != nil }
    }

    /// Writes the edge iPhone Duo's side rail runs down into `edge` — the
    /// trailing edge in portrait; in landscape whichever side the system
    /// picks for the way the phone is turned. Nil where there's no rail.
    func readsSideRailEdge(into edge: Binding<HorizontalEdge?>) -> some View {
        readsSideRail { edge.wrappedValue = $0 }
    }

    @ViewBuilder
    private func readsSideRail(_ write: @escaping (HorizontalEdge?) -> Void) -> some View {
        if #available(iOS 27.1, *) {
            modifier(SideRailReader(write: write))
        } else {
            self
        }
    }
}

@available(iOS 27.1, *)
private struct SideRailReader: ViewModifier {

    @Environment(\.toolbarVerticalEdge) private var edge
    let write: (HorizontalEdge?) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: edge, initial: true) { _, edge in write(edge) }
    }
}

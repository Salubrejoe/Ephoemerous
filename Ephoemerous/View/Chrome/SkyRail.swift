import SwiftUI

// MARK: - SkyRail
// iPhone Duo's side rail. On the outer display — and the inner one in
// landscape — the system stacks bars down the trailing edge, under the
// clock and the Dynamic Island. The sky's floating chrome moves INTO that
// rail as system toolbar items, so the system can keep it clear of the
// camera, share the column with Live Activities, overflow what won't fit
// and nudge it off the fold. Everywhere else this adds nothing and
// `SkyChrome` floats the usual glass.
//
// Top to bottom, the way the HIG orders a rail:
//   • where / when — the Here / Now capsule's pills as symbols (bars keep
//     text horizontal), with their go-back chips beside them
//   • the camera cluster — Orloj, projection flip, compass mode
//   • the compass rose — Apple's own example of a custom view that earns a
//     place in the rail
struct SkyRail: ViewModifier {

    @Environment(AppState.self) private var app

    /// The rail is up — see `readsSideRail(into:)`.
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.toolbar {
                if isActive { SkyRailItems(app: app) }
            }
        } else {
            content
        }
    }
}

// MARK: - SkyRailItems
@available(iOS 27.1, *)
private struct SkyRailItems: ToolbarContent {

    let app: AppState

    var body: some ToolbarContent {
        sceneGroup
        // Camera toggles are noise mid-picking — same rule as the
        // floating cluster.
        if !app.isShowingDatePicker && !app.isShowingLocationPicker {
            cameraGroup
        }
        if !app.isSkyUpright {
            rose
        }
    }

    /// Where and when — the capsule's two pills as symbols, flanked by
    /// their go-back chips when the scene has drifted off Here / Now. The
    /// labels still carry the words: the system shows them in the overflow
    /// menu and reads them to VoiceOver.
    private var sceneGroup: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if app.isAwayFromHere {
                Button("Back to Here", systemImage: "location.fill", action: app.goToDeviceLocation)
            }
            Button(action: app.toggleLocationPicker) {
                Label(app.placeLabel, systemImage: "mappin.and.ellipse")
            }
            Button(action: app.toggleDatePicker) {
                Label(app.timeLabel, systemImage: "calendar")
            }
            if app.isAwayFromNow {
                Button("Back to Now", systemImage: "clock.arrow.circlepath", action: app.returnToNow)
            }
        }
        .visibilityPriority(.high)
    }

    /// The camera capsule's buttons, bare — the rail's glass is their
    /// capsule now. Custom views, so they keep the flip's long-press into
    /// Look and the accent tint that says "engaged".
    private var cameraGroup: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
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
    @ViewBuilder
    func readsSideRail(into hasRail: Binding<Bool>) -> some View {
        if #available(iOS 27.1, *) {
            modifier(SideRailReader(hasRail: hasRail))
        } else {
            self
        }
    }
}

@available(iOS 27.1, *)
private struct SideRailReader: ViewModifier {

    @Environment(\.toolbarVerticalEdge) private var edge
    @Binding var hasRail: Bool

    func body(content: Content) -> some View {
        content.onChange(of: edge, initial: true) { _, edge in
            hasRail = edge != nil
        }
    }
}

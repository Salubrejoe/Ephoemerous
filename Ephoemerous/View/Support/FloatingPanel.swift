import SwiftUI

// MARK: - PanelStage
// The rest positions the search / detail surface can hold, named once so
// the two PRESENTATIONS can't drift apart.
//
// In compact width the surface is a real sheet and these map onto
// `PresentationDetent`s (the system owns the drag, the rubber-banding and
// the keyboard avoidance). In regular width there is no sheet — a sheet's
// horizontal position is not configurable in SwiftUI or UIKit, so a
// bottom-LEADING card can only be a view the app places itself.
//
// The panel holds all three, as the sheet does: parked at the bar, medium
// — its top at the screen's middle, where a place card opens — and large,
// nearly the full height. A swipe moves one stage at a time.
enum PanelStage: CaseIterable {
    case bar, medium, large

    /// Parked height — one band. The search card is a 16pt handle strip
    /// above a 44pt field with 14 below; the detail card's 16 + 44 + 14
    /// header lands in the same place.
    /// 16 + 44 + 16: the 44pt field inset 16 on EVERY side (the handle
    /// band above it is 16 too), so its radius 22 + 16 = the bar's 38 —
    /// exactly concentric. ▼ TWEAK ▼
    static let barHeight: CGFloat = 76

    var isOpen: Bool { self != .bar }
}

// MARK: - FloatingPanel
// The iPad's bottom-LEADING card, in the Apple-Maps grammar: a fixed-width
// floating surface over a fully live canvas, never a modal. The sky keeps
// the whole screen; the panel takes a corner of it.
//
// Deliberately NOT a sheet. On iPad a `.sheet` with detents presents as a
// bottom-CENTRED card and there is no API — SwiftUI or UIKit — to move it
// to an edge. So in regular width MainView stops presenting and starts
// placing, and this is what it places.
//
// One panel, not two: search and the detail place-card share this
// container and swap their CONTENTS, which is what Maps does and what the
// existing `searchPresented` / `detailDestination` swap already models.
//
// HEIGHT is three explicit stages — parked at `PanelStage.barHeight`,
// `medium`, or open to `cap` — with the drag interpolating between them. Sizing the
// open card to its CONTENT is still wanted; see `height` for what has
// already been tried and why it failed.
struct FloatingPanel<Content: View>: View {

    @Binding var stage: PanelStage
    /// Height available to the panel — the screen, which is what MainView's
    /// outer GeometryReader publishes. Passed in rather than read from a
    /// GeometryReader here so the panel doesn't force a layout pass on the
    /// sky behind it.
    let available: CGFloat
    /// Whether the panel draws its own drag band across the header.
    ///
    /// True for the detail card, whose header band is inert chrome between
    /// two buttons. FALSE for search, where those same pixels are the text
    /// field: a band over it swallows the tap that should raise the
    /// keyboard. Search carries the swipe itself instead, as a
    /// `simultaneousGesture` on the field, so tap and swipe coexist.
    var showsDragBand: Bool = true
    /// A width of its own, in place of the iPad's fixed `width` — iPhone
    /// Duo's outer display runs the card from the leading margin to the
    /// side rail (see MainView).
    var cardWidth: CGFloat? = nil
    /// Sky to leave above the card when it's all the way up, in place of
    /// the status bar's `topClearance` — iPhone Duo's inner display in
    /// portrait stops it under the centred Here / Now capsule, or under the
    /// hinge when folded (see MainView).
    var topInset: CGFloat? = nil
    /// Reports how far past medium the card is, 0 at medium and below … 1
    /// fully open, live through a drag — the place card's header and
    /// picture follow it as the iPhone sheet's follow `bottomSheetTop`.
    var onExpansion: (CGFloat) -> Void = { _ in }
    @ViewBuilder var content: Content

    /// Apple Maps' iPad card is ~320pt; this one carries a search field
    /// plus favourite cards, so it runs a little wider. ▼ TWEAK ▼
    static var width: CGFloat { 380 }

    /// Inset from the screen's leading and bottom edges.
    static var margin: CGFloat { 16 }

    /// How much of the screen's width the card takes, margin included —
    /// the sky centres in what's left (see `MainView.panelHome`).
    static var footprint: CGFloat { width + margin }

    /// How far a drag must travel before it changes stage.
    private static var dragThreshold: CGFloat { 44 }

    /// The header's own inset from the card edge — `DetailHeader`'s 6 + 10.
    private static var headerInset: CGFloat { 16 }

    /// Header button diameter (`CircleIconLabel`).
    private static var buttonSize: CGFloat { 44 }

    /// CONCENTRIC with the header's buttons: an inner radius plus the gap
    /// around it. The buttons are 22pt-radius circles sitting `headerInset`
    /// from the card's edges, so the card's corner has to be 38 for the two
    /// curves to share a centre. Anything else and the button reads as
    /// dropped into the corner rather than nested in it.
    private static var cornerRadius: CGFloat { buttonSize / 2 + headerInset }

    /// Capped at half the height, so the PARKED card is a true capsule
    /// (radius 40 at 80pt) and the search field — a 44pt capsule inset 18
    /// — is exactly concentric inside it. Opening interpolates the corner
    /// back down to 38, where it nests the header's buttons instead.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: min(Self.cornerRadius, height / 2),
                         style: .continuous)
    }

    /// Live drag, in points, positive DOWN. `@GestureState` rather than
    /// `@State`: it resets itself when the gesture ends, so a cancelled or
    /// interrupted drag can't strand the card at an offset height.
    @GestureState private var drag: CGFloat = 0
    // Measured in GLOBAL space: the handle rides the card's top edge, so a
    // local translation shrinks as the card does and the height chased
    // its own tail — a slow drag jittered up and down.

    /// The tallest the card may grow: (nearly) the full height of the
    /// screen, like Maps' card pulled up — search and the place card alike.
    /// The card sits beside the sky, not over it, so there's no reason to
    /// stop short.
    private var cap: CGFloat {
        max(200, available - Self.margin - (topInset ?? Self.topClearance))
    }

    /// Sky left above an open card — the status bar and a breath.
    private static var topClearance: CGFloat { 44 }

    private var dragging: Bool { drag != 0 }

    /// The medium stage: the card's top at the screen's middle, as the
    /// iPhone's medium detent. Never taller than `cap` — folded like a
    /// laptop the cap IS the lower half, and medium and large meet.
    private var medium: CGFloat {
        min(cap, max(PanelStage.barHeight, available / 2 - Self.margin))
    }

    /// A stage's resting height.
    private func restHeight(_ stage: PanelStage) -> CGFloat {
        switch stage {
        case .bar:    PanelStage.barHeight
        case .medium: medium
        case .large:  cap
        }
    }

    /// The stage one swipe away, up or down — skipping a stage that rests
    /// at the same height, so no swipe is ever spent on nothing.
    private func neighbour(of current: PanelStage, up: Bool) -> PanelStage {
        let all   = PanelStage.allCases
        let order = up ? all : all.reversed()
        let here  = restHeight(current)
        let start = order.firstIndex(of: current)! + 1
        return order[start...].first { restHeight($0) != here } ?? current
    }

    /// Settle a released drag: past the threshold, one stage that way.
    private func settle(_ translation: CGFloat) {
        guard abs(translation) > Self.dragThreshold else { return }
        withAnimation(.snappy(duration: 0.32)) {
            stage = neighbour(of: stage, up: translation < 0)
        }
    }

    /// ONE height, computed, with no branching anywhere near it.
    ///
    /// The previous pass swapped between `.frame(height:)` and
    /// `.frame(maxHeight:)` through an if/else in a ViewModifier. An
    /// if/else there is a STRUCTURAL change: the moment a drag began, the
    /// branch flipped, SwiftUI tore down the subtree carrying the gesture,
    /// and the gesture was cancelled before it could move anything — which
    /// is why the handle did nothing at all, and why the height oscillated.
    /// A single frame call with a computed value cannot do that.
    /// The card's height. ALWAYS a number.
    ///
    /// Two dead ends are worth recording, because both look right and
    /// neither is: an if/else between two different `.frame` calls
    /// restructures the view tree, so the drag gesture's own subtree was
    /// torn down the instant a drag began (the handle "did nothing").
    /// And `.frame(maxHeight:)` does not hug — it EXPANDS to the maximum
    /// whenever the parent proposes more, which in a bottom-leading
    /// overlay is the whole screen. The card was cap-tall in every stage
    /// with its content top-aligned inside, which is exactly the "content
    /// hides and shows but the container never moves" symptom.
    ///
    /// So: one modifier, one number, no branching. Hugging the content is
    /// still wanted (#5) and still unsolved — it needs the detail views'
    /// trailing `Spacer`s to stand down in a panel, which is a change in
    /// those views, not in this container.
    private var height: CGFloat {
        min(cap, max(PanelStage.barHeight, restHeight(stage) - drag))
    }

    var body: some View {
        VStack(spacing: 0) {
            // The detail card's handle is its header band, between the two
            // buttons. Search has no such band — those pixels are the text
            // field — so it gets a visible grabber instead, the way the
            // iPhone sheet does.
            if !showsDragBand { grabber }
            content
        }
            .frame(width: cardWidth ?? Self.width, height: height, alignment: .top)
            .clipShape(shape)
            // REGULAR, not clear. Clear glass let the sky through so
            // completely that the card had no edge — over a busy field of
            // stars and grid lines there was nothing separating the two.
            // The buttons inside stay `.clear`, so they still read as a
            // lighter species sitting ON the card rather than in it.
            .glassEffect(.regular.interactive(), in: shape)
            .shadow(color: .black.opacity(0.28), radius: 16, y: 5)
            .overlay(alignment: .top) {
                if showsDragBand { dragBand }
            }
            .padding(.leading, Self.margin)
            .padding(.bottom,  Self.margin)
            .onChange(of: height, initial: true) { _, h in
                onExpansion(cap - medium < 1 ? 0 : min(1, max(0, (h - medium) / (cap - medium))))
            }
    }

    /// The visible handle, for the surfaces that have no header band to
    /// use as one. Carries the same drag.
    private var grabber: some View {
        Capsule()
            .fill(.white.opacity(0.55))
            .frame(width: 40, height: 5)
            .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
            .frame(maxWidth: .infinity)
            .frame(height: 16)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .updating($drag) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in settle(value.translation.height) }
            )
    }

    /// The handle is the header band BETWEEN the two buttons — no separate
    /// grabber. Inset past a button on each side so the share and dismiss
    /// taps are never stolen, and only this band carries the gesture: the
    /// body is a scroll view and a text field, and taking their drags would
    /// make the results unscrollable.
    private var dragBand: some View {
        Color.clear
            .frame(height: Self.headerInset + Self.buttonSize)
            // ORDER MATTERS: shape and gesture BEFORE the padding. Applied
            // after, `contentShape` takes the padded frame — the inset is
            // part of the hit area, so the band covered the full header
            // width and ate the share and dismiss taps. Before, the hit
            // area is the inner region only and the buttons keep their
            // corners.
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .updating($drag) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in settle(value.translation.height) }
            )
            .padding(.horizontal, Self.headerInset + Self.buttonSize + 8)
    }
}

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
// The three cases exist for the SHEET's detent set. The panel has only two
// visual states — parked, or open — and `medium` / `large` both mean open
// there, so `SearchSheet`'s existing "typing lifts to medium, focus lifts
// to large" logic keeps working unchanged in both presentations.
enum PanelStage: CaseIterable {
    case bar, medium, large

    /// Parked height: the grabber strip plus a search field, or a detail
    /// card's header. The sheet's 72 worked because the SYSTEM drew the
    /// grabber inside the detent; the panel draws its own.
    static let barHeight: CGFloat = 96

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
// HEIGHT is two explicit stages — parked at `PanelStage.barHeight`, or
// open to `cap` — with the drag interpolating between them. Sizing the
// open card to its CONTENT is still wanted; see `height` for what has
// already been tried and why it failed.
struct FloatingPanel<Content: View>: View {

    @Binding var stage: PanelStage
    /// Height available to the panel — the screen, which is what MainView's
    /// outer GeometryReader publishes. Passed in rather than read from a
    /// GeometryReader here so the panel doesn't force a layout pass on the
    /// sky behind it.
    let available: CGFloat
    @ViewBuilder var content: Content

    /// Apple Maps' iPad card is ~320pt; this one carries a search field
    /// plus favourite cards, so it runs a little wider. ▼ TWEAK ▼
    static var width: CGFloat { 380 }

    /// Inset from the screen's leading and bottom edges.
    private static var margin: CGFloat { 20 }

    /// How far a drag must travel before it changes stage.
    private static var dragThreshold: CGFloat { 44 }

    /// The grabber's strip at the top of the card.
    private static var grabberStrip: CGFloat { 22 }

    /// Live drag, in points, positive DOWN. `@GestureState` rather than
    /// `@State`: it resets itself when the gesture ends, so a cancelled or
    /// interrupted drag can't strand the card at an offset height.
    @GestureState private var drag: CGFloat = 0

    /// The tallest the card may grow. Matters most in landscape, where a
    /// larger fraction would leave no sky at all.
    private var cap: CGFloat { max(200, available * 0.72 - Self.margin) }

    private var dragging: Bool { drag != 0 }

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
        let rest = stage.isOpen ? cap : PanelStage.barHeight
        return min(cap, max(PanelStage.barHeight, rest - drag))
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            content
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(width: Self.width, height: height, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(.regularMaterial,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        .padding(.leading, Self.margin)
        .padding(.bottom,  Self.margin)
    }

    /// The drag handle — and the only thing carrying the gesture. The body
    /// is a scroll view and a text field; stealing their drags would make
    /// the results unscrollable.
    ///
    /// `.secondary` on `regularMaterial` was invisible on the sky at this
    /// size, so it is drawn in plain white at a fixed opacity, a point
    /// thicker, with a hairline shadow under it. ▼ TWEAK ▼
    private var grabber: some View {
        Capsule()
            .fill(.white.opacity(0.55))
            .frame(width: 40, height: 6)
            .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
            .frame(maxWidth: .infinity)
            .frame(height: Self.grabberStrip)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .updating($drag) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let d = value.translation.height
                        withAnimation(.snappy(duration: 0.32)) {
                            if d < -Self.dragThreshold { stage = .large }
                            if d >  Self.dragThreshold { stage = .bar }
                        }
                    }
            )
    }
}

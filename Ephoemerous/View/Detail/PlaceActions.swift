import SwiftUI
import LoreKit

// MARK: - PlaceActionRow
// The buttons at the head of a place card's grid, the Apple Maps way: a row
// of equal glass buttons, each an icon over its label.
//
//   star          Pin · Find · Constellation
//   constellation Trace · Find · Story
//   craft, Moon,
//   planet        Find (the one button, full width)
//
// A button has one of three tones:
//   .prominent — the call to action: accent glass, dark ink. Pin, until pinned.
//   .engaged   — a state that's on: quiet glass, accent ink. Pinned, Story open.
//   .quiet     — everything else: quiet glass, ink.
// "Accent = live / engaged" — see the vanity rulebook.
struct PlaceActionRow<Content: View>: View {

    @ViewBuilder let content: () -> Content

    var body: some View {
        GlassEffectContainer(spacing: Artist.shared.detailGridSpacing) {
            HStack(spacing: Artist.shared.detailGridSpacing) { content() }
        }
    }
}

enum PlaceActionTone { case prominent, engaged, quiet }

// MARK: Face
/// One button's look: the icon over its label on a glass tile.
struct PlaceActionFace<Icon: View>: View {

    let title:   String
    var tone:    PlaceActionTone = .quiet
    var enabled: Bool            = true
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        let a     = Artist.shared
        let shape = RoundedRectangle(cornerRadius: a.placeActionRadius, style: .continuous)
        VStack(spacing: 5) {
            icon()
                .font(.title3.weight(.semibold))
                .frame(height: 24)
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity)
        .frame(height: a.placeActionHeight)
        .contentShape(shape)
        .glassEffect(tone == .prominent ? .regular.tint(Color.accentColor).interactive()
                                        : .regular.interactive(),
                     in: shape)
        .opacity(enabled ? 1 : 0.4)
    }

    private var ink: Color {
        switch tone {
        case .prominent: .black.opacity(0.85)
        case .engaged:   Color.accentColor
        case .quiet:     .primary
        }
    }
}

// MARK: Button
struct PlaceActionButton<Icon: View>: View {

    let title:   String
    var tone:    PlaceActionTone = .quiet
    var enabled: Bool            = true
    let action:  () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            PlaceActionFace(title: title, tone: tone, enabled: enabled, icon: icon)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Pin
/// Pin a star or constellation — keeps it on the map at every zoom. A
/// constellation words it "Trace", with its own stick figure for the glyph;
/// the logic is the same.
struct PinAction: View {

    @Environment(AppState.self) private var state
    let object: SkyObject

    var body: some View {
        let pinned = state.isFavourite(object)
        PlaceActionButton(title:  title(pinned),
                          tone:   pinned ? .engaged : .prominent,
                          action: { state.toggleFavourite(object) }) {
            if case .constellation(let c) = object {
                Artist.shared.constellationFigure(c)
            } else {
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .contentTransition(.symbolEffect(.replace.downUp))
            }
        }
        .sensoryFeedback(.success, trigger: pinned) { _, now in now }
        .animation(.bouncy, value: pinned)
    }

    private func title(_ pinned: Bool) -> String {
        if case .constellation = object {
            return pinned ? String(localized: "Traced") : String(localized: "Trace")
        }
        return pinned ? String(localized: "Pinned") : String(localized: "Pin")
    }
}

// MARK: - Find
/// Hunt this object through the window. Where the window can't open (not
/// where you stand, or no gyro) it dims in a row of three — so the row
/// doesn't shift — and is left out when it would stand alone.
struct FindAction: View {

    @Environment(AppState.self) private var state
    /// The row's only button: hidden, not dimmed, when it can't work.
    var solo: Bool = false

    var body: some View {
        if solo && !state.canLook {
            EmptyView()
        } else {
            PlaceActionButton(title:   String(localized: "Find"),
                              enabled: state.canLook,
                              action:  { state.enterLook() }) {
                Image(systemName: "scope")
            }
        }
    }
}

// MARK: - Story
/// A constellation's catasterism — how the figure got into the sky — shown
/// or hidden in its card's grid. Off until asked for.
struct StoryAction: View {

    @Binding var isOn: Bool

    var body: some View {
        PlaceActionButton(title:  String(localized: "Story"),
                          tone:   isOn ? .engaged : .quiet,
                          action: { isOn.toggle() }) {
            Image(systemName: isOn ? "book.fill" : "book")
        }
    }
}

// MARK: - Constellation
/// From a star to the constellation it belongs to, under its own figure and
/// its own name.
/// Pushed onto the sheet's stack; in the iPad's floating panel (no stack)
/// selected, so the panel becomes the constellation's card; and when the
/// star was itself opened FROM that constellation, simply back.
struct ConstellationAction: View {

    @Environment(AppState.self)   private var state
    @Environment(\.detailInPanel) private var inPanel
    @Environment(\.dismiss)       private var dismiss

    let constellation: Constellation
    /// This star was pushed from its constellation's card.
    var cameFromConstellation: Bool = false

    var body: some View {
        let face = PlaceActionFace(title: constellation.localizedName) {
            Artist.shared.constellationFigure(constellation)
        }
        Group {
            if cameFromConstellation {
                Button { dismiss() } label: { face }
            } else if inPanel {
                Button { state.focus(on: .constellation(constellation)) } label: { face }
            } else {
                NavigationLink(value: constellation) { face }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(String(localized: "Constellation")), \(constellation.localizedName)"))
    }
}

// MARK: - Sticky
// The row rides the scroll: it sits under the picture, rises with it, and
// stops against the title. From there the tiles pass UNDER it — but never
// show through or around it: the scroll view is masked just below the row,
// so a tile dissolves at that line and nothing draws over the header.
//
// The scroll offset lives in an `@Observable` read only by these two small
// views, so a scroll tick redraws the row's offset and the mask — not the
// sheet and its tiles.

/// The grid's scroll offset, for the views that follow it.
@Observable
final class PlaceScroll {
    var y: CGFloat = 0
}

/// The action row, floated over the scroll view at the height the content
/// would put it, then held at the top once the picture has gone.
struct StickyPlaceActions<Content: View>: View {

    let scroll:     PlaceScroll
    let heroHeight: CGFloat
    /// The row's own height (padding included), reported up so the scroll
    /// content can leave room for it. 0 when there's no row to show.
    @Binding var rowHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            // Its own height, not whatever the overlay offers: a glass
            // container will take all the room it is proposed.
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                rowHeight = h > 1 ? h + Self.pad * 2 : 0
            }
            .padding(.horizontal, 16)
            .padding(.vertical, Self.pad)
            .offset(y: max(0, heroHeight - max(0, scroll.y)))
    }

    static var pad: CGFloat { 8 }
}

/// Hides the scroll view above the row once the row is stuck — a clean edge
/// just under the buttons, with a short fade so a tile dissolves into it.
struct StickyMask: View {

    let scroll:     PlaceScroll
    let heroHeight: CGFloat
    let rowHeight:  CGFloat

    var body: some View {
        let rowTop = max(0, heroHeight - max(0, scroll.y))
        let stuck  = rowHeight > 0 ? 1 - min(1, rowTop / rowHeight) : 0
        VStack(spacing: 0) {
            Color.clear.frame(height: rowHeight * stuck)
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 10 * stuck)
            Color.black
        }
    }
}

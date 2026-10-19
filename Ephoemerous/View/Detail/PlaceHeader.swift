import SwiftUI
import LoreKit

// MARK: - PlaceHeader
// The detail sheet's header, the Apple Maps way — one title view, centred
// on the toolbar's own row, that grows as the sheet is pulled up and
// settles back as it lowers, riding the drag (`AppState.bottomSheetTop`)
// rather than swapping layouts:
//
//   {share}     TITLE      {✕}
//              α Persei
//          (the object's sky)
//
// Pulled all the way up the title is big with headroom above it; scrolling
// the body eases the header back toward its resting size. Folded to the
// header-only detent it's the first row alone, the title over the live
// status line ("● Up · 31° NW · never sets").
//
// Share keeps the toolbar's leading corner; the action row (`PlaceActionRow`)
// heads the sheet's grid, the way Apple Maps lays out a place's buttons.
struct PlaceHeader: View {

    @Environment(AppState.self)  private var state
    @Environment(\.detailCollapsed) private var collapsed
    @Environment(\.layoutDirection) private var layoutDirection

    let object:    SkyObject
    let title:     String
    /// Under the title when the sheet is open — a star's designation.
    let subtitle:  String
    /// The toolbar's leading button — Share by default.
    var leading:   Leading = .share
    let onDismiss: () -> Void
    /// iPhone Duo's outer display: the sheet's rail carries share (see
    /// `PlaceRail`), and the row is the Duo's own — see `railRow`.
    var railed: Bool = false

    /// Where the row's top sits on screen — the rail row aims its title at
    /// the camera's line from here. Independent of the row's own padding.
    @State private var rowTopOnScreen: CGFloat?
    /// The rail row's title block (title + subtitle) and the title line
    /// alone — measured, so the block centres on ✕ and the title on the
    /// camera without guessing line heights. Neither moves with its padding.
    @State private var railBlockHeight: CGFloat = 0
    @State private var railTitleHeight: CGFloat = 0

    /// What sits in the toolbar's leading corner.
    enum Leading {
        /// The object's postcard.
        case share
        /// Any other one-tap job — back to the roster, back to now.
        case button(LoreSymbol, () -> Void)
    }

    var body: some View {
        // Follows the SHEET's drag only — never the scroll. A header that
        // resized with the scroll changed the scroll view's own height
        // under the finger: the two chased each other, worst in the bounce
        // at the bottom, where native inertia turned into a jitter.
        let e = collapsed ? 0 : state.detailSheetExpansion
        if railed {
            railRow(e)
        } else {
            toolbar(e)
                .padding(.bottom, collapsed ? 6 : 8)
        }
    }

    /// Title size, from the folded bar through the resting sheet to the
    /// fully raised one.
    private func titleSize(_ e: CGFloat) -> CGFloat {
        let a = Artist.shared
        return collapsed ? a.placeTitleSize.lowerBound - 4
                         : a.placeTitleSize.lowerBound
                           + (a.placeTitleSize.upperBound - a.placeTitleSize.lowerBound) * e
    }

    // MARK: Toolbar row

    /// {share} TITLE {✕} — the title centred on the buttons' own row, its
    /// subtitle hung beneath.
    private func toolbar(_ e: CGFloat) -> some View {
        let a    = Artist.shared
        let size = titleSize(e)
        return HStack(alignment: .top) {
            switch leading {
            case .share:                     share
            case .button(let symbol, let action): CircleIconButton(symbol: symbol, action: action)
            }
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: size, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if collapsed {
                    SkyStatusLine(object: object)
                } else {
                    Text(subtitle)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, collapsed ? 2 : a.placeTitleHeadroom * e + 4)
            CircleIconButton(symbol: .xmark, action: onDismiss)
        }
        .padding(.horizontal, 16)
        .padding(.top, collapsed ? 12 : 14)
    }

    // MARK: Rail row (iPhone Duo)

    /// iPhone Duo's outer display — the title block on the LEADING edge, in
    /// line with the tiles, and ✕ drawn here rather than in the rail, so it
    /// can sit concentric with the card's corner:
    ///
    ///   folded  — title over the status line, centred in the bar and set
    ///             in from the capsule's curve; ✕ centred at its end
    ///   resting — title and subtitle centred, as a pair, on ✕
    ///   raised  — the title rides up to the front camera's line (the sky's
    ///             Here / Now line); ✕ steps down clear of the clock
    ///
    /// Open, the block lines up with the tiles' CONTENT, not their edge.
    /// The row runs under the sheet's rail column, so ✕ measures its inset
    /// from the card's real edge.
    private func railRow(_ e: CGFloat) -> some View {
        let a = Artist.shared
        let closeInset = collapsed ? a.placeFoldedHeight / 2 - a.placeRailButton / 2
                                   : a.placeRailInset
        return VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: titleSize(e), weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                        railTitleHeight = h
                    }
                if collapsed {
                    SkyStatusLine(object: object)
                } else {
                    Text(subtitle)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                railBlockHeight = h
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, collapsed ? 0 : railTitleTop(e))
            .padding(.leading,  collapsed ? a.placeFoldedLeading : a.placeRailTitleLeading)
            // Room for ✕ beside the block, so a long title can't run under it.
            .padding(.trailing, closeInset + a.placeRailButton + 12)
            .frame(height: collapsed ? a.placeFoldedHeight : nil)
            // Open, a full grid gap under the subtitle — the scroll's top
            // edge — so header to first tile matches tile to tile.
            .padding(.bottom, collapsed ? 0 : a.detailGridSpacing)
            // ✕ FLOATS over the row rather than standing in it: raised, it
            // steps down below the clock, and in the row it made the header
            // that tall — a blank band between the title and the tiles.
            .overlay(alignment: collapsed ? .trailing : .topTrailing) {
                CircleIconButton(symbol: .xmark, action: onDismiss)
                    .padding(.top,      collapsed ? 0 : railCloseTop)
                    .padding(.trailing, closeInset)
            }
        .ignoresSafeArea(.container, edges: layoutDirection == .rightToLeft ? .leading : .trailing)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
            rowTopOnScreen = top
        }
    }

    /// ✕'s drop from the card's top: the concentric inset — until the card
    /// rises under the rail's clock, when it steps down to stay clear.
    private var railCloseTop: CGFloat {
        let inset = Artist.shared.placeRailInset
        guard let statusBottom = state.skyRailStatusBottom,
              let rowTop       = rowTopOnScreen
        else { return inset }
        return max(inset, statusBottom + 8 - rowTop)
    }

    /// The title block's drop from the card's top: centred on ✕ at rest,
    /// gliding until the title line sits on the camera's line as the card
    /// rises.
    private func railTitleTop(_ e: CGFloat) -> CGFloat {
        let closeMid = railCloseTop + Artist.shared.placeRailButton / 2
        let onClose  = max(0, closeMid - railBlockHeight / 2)
        guard let cameraMidY = state.skyCameraMidY,
              let rowTop     = rowTopOnScreen
        else { return onClose }
        let onCamera = max(0, cameraMidY - rowTop - railTitleHeight / 2)
        return onClose + (onCamera - onClose) * e
    }

    private var share: some View {
        ShareLink(item:    state.postcard(for: object),
                  subject: Text(title),
                  message: Text(state.postcard(for: object).message),
                  preview: SharePreview(title)) {
            CircleIconLabel(symbol: .share)
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Knobs
extension Artist {
    /// ▼ TWEAK the place header ▼
    /// Title size from the resting sheet to the fully raised one.
    var placeTitleSize:      ClosedRange<CGFloat> { 24 ... 36 }
    /// Headroom above the title once the sheet is fully raised.
    var placeTitleHeadroom:  CGFloat { 22 }
    /// iPhone Duo's card: ✕'s inset from the card's top and trailing edges
    /// — concentric with a ~38pt corner round a 44pt button — and the
    /// tiles' leading inset, which the title lines up with.
    var placeRailInset:      CGFloat { 16 }
    var placeRailButton:     CGFloat { 44 }
    /// The folded card's height — the header detent (see MainView).
    var placeFoldedHeight:   CGFloat { 70 }
    /// The open card's title block lines up with the tiles' content: the
    /// grid's 16 plus a tile's own 14.
    var placeRailTitleLeading: CGFloat { 16 + detailCardPadding }
    /// The folded bar's title block, set in from the capsule's curve.
    /// ▼ TWEAK ▼
    var placeFoldedLeading:  CGFloat { 26 }
    /// The object's picture under the title — its height at rest, what it
    /// gains as the sheet rises, and what scrolling the body takes back.
    var placeHeroHeight:     CGFloat { 100 }
    var placeHeroGrowth:     CGFloat { 50 }
    /// The height of the object's picture at a given sheet expansion — 0 once
    /// it's too small to show. `PlaceHero` draws to it; the sticky action row
    /// rises to meet it.
    func placeHeroBlockHeight(reveal: CGFloat, scale: CGFloat) -> CGFloat {
        let h = (placeHeroHeight + placeHeroGrowth * reveal) * scale * reveal
        return h > 4 ? h : 0
    }
    /// The action row at the grid's head — Pin / Find / …, icon over label.
    var placeActionHeight:   CGFloat { 62 }
    var placeActionRadius:   CGFloat { 20 }
    /// How far past the grid's top a pull must go to fold the card. ▼ TWEAK ▼
    var placePullToFold:     CGFloat { 70 }
}

// MARK: - PlaceHero
// The object's picture, at the top of the sheet's SCROLLING content — so it
// scrolls away with native inertia instead of being resized by the scroll.
// It's the full-screen sheet's: it grows in with the drag from nothing at
// the resting third, fading as it comes, so the low sheets go straight from
// title to grid.
struct PlaceHero: View {

    @Environment(AppState.self) private var state

    let object: SkyObject
    /// How much taller than the standard picture this object's is — a
    /// constellation's header IS its figure, with names, so it gets room.
    var scale:  CGFloat = 1
    /// The grid's scroll — the picture shrinks away as the tiles rise.
    let scroll: PlaceScroll

    var body: some View {
        let a      = Artist.shared
        let reveal = state.detailSheetExpansion
        let height = a.placeHeroBlockHeight(reveal: reveal, scale: scale)
        if height > 0 {
            // No ground of its own — the stars sit on the sheet's sky.
            HeroBanner(object:      object,
                       height:      height,
                       ground:      false,
                       photos:      false,
                       figureMarks: true)
                // Fade in at the top too, so the picture rises out of the
                // sheet's night instead of starting on an edge.
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                                             .init(color: .black, location: 0.25)],
                                     startPoint: .top, endPoint: .bottom))
                .opacity(Double(reveal))
                .modifier(ShrinksIntoScroll(scroll: scroll, height: height))
        }
    }
}

// MARK: - ShrinksIntoScroll
// The picture scales down to nothing as the grid scrolls up — the same
// move it makes when the sheet lowers — instead of sliding under the title
// and being cut flat by it. Scaled from its BOTTOM in step with the scroll,
// its top edge stays put at the scroll's top while it shrinks, so the
// title never cuts it. A visual effect only, so it can't push back on the
// scroll; and its own small view, so a scroll tick redraws just this.
private struct ShrinksIntoScroll: ViewModifier {
    let scroll: PlaceScroll
    let height: CGFloat

    func body(content: Content) -> some View {
        let left = max(0, 1 - max(0, scroll.y) / max(1, height))
        content
            .scaleEffect(left, anchor: .bottom)
            .opacity(Double(left))
    }
}

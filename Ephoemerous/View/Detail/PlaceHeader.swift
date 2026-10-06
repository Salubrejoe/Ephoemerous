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

    let object:    SkyObject
    let title:     String
    /// Under the title when the sheet is open — a star's designation.
    let subtitle:  String
    /// The toolbar's leading button — Share by default.
    var leading:   Leading = .share
    let onDismiss: () -> Void

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
        toolbar(e)
            .padding(.bottom, collapsed ? 6 : 8)
    }

    // MARK: Toolbar row

    /// {share} TITLE {✕} — the title centred on the buttons' own row, its
    /// subtitle hung beneath.
    private func toolbar(_ e: CGFloat) -> some View {
        let a    = Artist.shared
        let size = collapsed ? a.placeTitleSize.lowerBound - 4
                             : a.placeTitleSize.lowerBound
                               + (a.placeTitleSize.upperBound - a.placeTitleSize.lowerBound) * e
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
                // Fades as it scrolls off under the title — a visual
                // transition only, so it can't push back on the scroll.
                .scrollTransition(.interactive, axis: .vertical) { hero, phase in
                    hero.opacity(1 + min(0, phase.value))
                }
        }
    }
}

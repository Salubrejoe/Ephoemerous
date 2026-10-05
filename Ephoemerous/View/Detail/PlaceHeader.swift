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
// Share keeps the toolbar's leading corner; Remember and Find live at the
// foot of the sheet's grid (`PlaceActions`), out of the content's way.
struct PlaceHeader: View {

    @Environment(AppState.self)  private var state
    @Environment(\.detailCollapsed) private var collapsed

    let object:    SkyObject
    let title:     String
    /// Under the title when the sheet is open — a star's designation.
    let subtitle:  String
    /// 0…1 — how far the sheet's body has scrolled; the header eases back
    /// toward its resting size with it.
    var scrolled:  CGFloat = 0
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
        let a = Artist.shared
        let e = collapsed ? 0 : state.detailSheetExpansion * (1 - min(1, max(0, scrolled)))
        VStack(spacing: 0) {
            toolbar(e)
            // The picture is the FULL-SCREEN sheet's: it grows in with the
            // drag from nothing at the resting third, fading as it comes —
            // so the low sheets go straight from title to grid.
            let reveal = state.detailSheetExpansion
            let height = max(0, (a.placeHeroHeight + a.placeHeroGrowth * e) * reveal
                                - a.placeHeroScrollGive * min(1, max(0, scrolled)))
            if !collapsed, height > 4 {
                // No ground of its own — the stars sit on the sheet's sky.
                HeroBanner(object: object,
                           height: height,
                           ground: false,
                           photos: false)
                    // Fade in at the top too, so the picture rises out of
                    // the sheet's night instead of starting on an edge.
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                                                 .init(color: .black, location: 0.25)],
                                         startPoint: .top, endPoint: .bottom))
                    .opacity(Double(reveal))
            }
        }
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
    var placeHeroScrollGive: CGFloat { 50 }
    /// Remember / Find — full-width capsules at the grid's foot.
    var placeActionHeight:   CGFloat { 50 }
    /// Scroll distance (pt) over which the header eases back.
    var placeScrollRange:    CGFloat { 140 }
}

// MARK: - PlaceActions
// The sheet's two actions, at the foot of its grid — full width, stacked,
// out of the content's path:
//   Remember — the heart, pink once remembered (the app's one favourite
//              colour), a success tap on the way in.
//   Find     — the window, hunting this object (it's already the
//              selection). Only shown when the window can open: where you
//              stand, with a gyro to steer.
struct PlaceActions: View {

    @Environment(AppState.self) private var state
    let object: SkyObject
    /// Stars only — the Sun, Moon and planets aren't favourited.
    var remember: Bool = true
    /// Not for the Sun — no one should go hunting it through a phone.
    var find:     Bool = true

    var body: some View {
        let remembered = state.isFavourite(object)
        GlassEffectContainer(spacing: Artist.shared.detailGridSpacing) {
            VStack(spacing: Artist.shared.detailGridSpacing) {
                if remember {
                capsule {
                    state.toggleFavourite(object)
                } label: {
                    Label(remembered ? String(localized: "Remembered") : String(localized: "Remember"),
                          systemImage: remembered ? "heart.fill" : "heart")
                        .foregroundStyle(remembered ? Color.pink : .primary)
                        .contentTransition(.symbolEffect(.replace.downUp))
                }
                .sensoryFeedback(.success, trigger: remembered) { _, now in now }
                }

                if find, state.canLook {
                    capsule {
                        state.enterLook()
                    } label: {
                        Label(String(localized: "Find in the sky"), systemImage: "scope")
                    }
                }
            }
        }
        .animation(.bouncy, value: remembered)
    }

    private func capsule<L: View>(_ action: @escaping () -> Void,
                                  @ViewBuilder label: () -> L) -> some View {
        Button(action: action) {
            label()
                .font(.body.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
                .frame(height: Artist.shared.placeActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

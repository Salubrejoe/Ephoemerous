import SwiftUI
import LoreKit

// MARK: - DetailHeader
// Apple-Maps place-card-style header used by every detail view.
//
// EXPANDED (with a hero object):
//   ┌────────────────────────────────────────┐
//   │ [share]      credit, faintly    [xmark]│
//   │            rendered sky + body         │
//   │ Title                              (♥) │  ← heart: stars, constellations
//   │ ● Up · 41° W · sets 14:20              │  ← one live subtitle
//   └────────────────────────────────────────┘
// COLLAPSED (or no hero):
//   [leading] [secondary?]    TITLE        [xmark]
//                       ● status / subtitle
//
// The subtitle is the object's live status (`SkyStatusLine`) wherever
// there's an object to read it from; what a thing IS (its type, its
// phase, its namesake) lives in the rows below, not up here.
//
// Leading button is parameterised (`leadingSymbol` + `onLeading`) so
// different detail surfaces can use it for different jobs — share for
// constellation / planet today, back-chevron for star (which can be
// reached via a push from the constellation roster, so it needs an
// affordance to pop). An optional secondary leading button sits to the
// right of the primary; the X-mark dismisses via the host's closure.
//
// `icon` and `accent` are kept on the initialiser for the callers but no
// longer drawn — the hero shows the body itself.
struct DetailHeader<Icon: View>: View {
    /// When the sheet is folded to its header-only detent, drop the POI
    /// icon so the visible band is just title + subtitle + buttons.
    @Environment(\.detailCollapsed) private var collapsed

    let title:                  String
    let subtitle:               String
    let accent:                 Color
    let icon:                   Icon
    let leadingSymbol:          LoreSymbol
    let onLeading:              () -> Void
    let secondaryLeadingSymbol: LoreSymbol?
    let onSecondaryLeading:     (() -> Void)?
    let onNow:                  (() -> Void)?
    let nowIsActive:            Bool
    let onDismiss:              () -> Void
    /// The postcard this sheet can send. When present, whichever slot
    /// carries `.share` becomes a real `ShareLink` instead of a plain
    /// button — ShareLink owns the sheet, the iPad popover anchor, and
    /// renders the image lazily (see `SkyPostcard`).
    let postcard:               SkyPostcard?
    /// The object whose picture tops the expanded header (see
    /// `HeroBanner`). nil, or a collapsed sheet, keeps the compact header.
    let hero:                   SkyObject?
    /// The object the trailing heart favourites — stars and constellations
    /// only. nil draws no heart.
    let favorite:               SkyObject?
    /// Replaces the live status under the expanded title — a star shows
    /// its designation there, its rise/set living in the grid below.
    let heroSubtitle:           String?

    init(title:                  String,
         subtitle:               String,
         accent:                 Color,
         @ViewBuilder icon:      () -> Icon,
         leadingSymbol:          LoreSymbol,
         onLeading:              @escaping () -> Void,
         secondaryLeadingSymbol: LoreSymbol?       = nil,
         onSecondaryLeading:     (() -> Void)?     = nil,
         onNow:                  (() -> Void)?     = nil,
         nowIsActive:            Bool              = false,
         postcard:               SkyPostcard?      = nil,
         hero:                   SkyObject?        = nil,
         favorite:               SkyObject?        = nil,
         heroSubtitle:           String?           = nil,
         onDismiss:              @escaping () -> Void) {
        self.heroSubtitle           = heroSubtitle
        self.hero                   = hero
        self.favorite               = favorite
        self.postcard               = postcard
        self.title                  = title
        self.subtitle               = subtitle
        self.accent                 = accent
        self.icon                   = icon()
        self.leadingSymbol          = leadingSymbol
        self.onLeading              = onLeading
        self.secondaryLeadingSymbol = secondaryLeadingSymbol
        self.onSecondaryLeading     = onSecondaryLeading
        self.onNow                  = onNow
        self.nowIsActive            = nowIsActive
        self.onDismiss              = onDismiss
    }

    var body: some View {
        if let hero, !collapsed {
            heroLayout(hero)
        } else {
            compactLayout
        }
    }

    /// Expanded with a picture (layout B): the banner full-bleed on top with
    /// the buttons floating on it, the name and its live status sitting
    /// left-aligned on the banner's fade — an Apple Maps place card — and a
    /// photographed body's credit whispered along the picture's top edge.
    private func heroLayout(_ hero: SkyObject) -> some View {
        let banner = HeroBanner(object: hero)
        return ZStack(alignment: .bottomLeading) {
            banner
                .overlay(alignment: .top) {
                    ZStack(alignment: .top) {
                        if let credit = banner.credit {
                            Text(verbatim: credit)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.45))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 76)      // clear of the buttons
                                .padding(.top, 6)
                        }
                        buttonRow
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                    }
                }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    titleText
                    if let heroSubtitle {
                        Text(heroSubtitle)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        SkyStatusLine(object: hero)
                    }
                }
                Spacer(minLength: 0)
                if let favorite { FavoriteCircleButton(obj: favorite) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 2)
        }
        .padding(.bottom, 6)
    }

    /// Collapsed (or no picture): the title on the BUTTONS' axis — centre
    /// alignment, not top — so the three read as one row. The live status
    /// stands in for the subtitle whenever there's an object to read it from.
    private var compactLayout: some View {
        ZStack {
            VStack(spacing: 4) {
                titleText
                if let hero {
                    SkyStatusLine(object: hero)
                } else {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            buttonRow
                .padding(.horizontal, 10)
        }
        .padding(.top, 16)
        .padding(.horizontal, 6)
        .padding(.bottom, 8)
    }

    private var titleText: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.primary)
    }

    private var buttonRow: some View {
        HStack(spacing: 8) {
            slot(leadingSymbol, onLeading)
            if let sym = secondaryLeadingSymbol,
               let act = onSecondaryLeading {
                slot(sym, act)
            }
            Spacer()

            CircleIconButton(symbol: .xmark, action: onDismiss)
        }
    }

    /// One header slot. The share symbol becomes a `ShareLink` when this
    /// sheet has a postcard to send; everything else stays a plain button.
    /// Both wear the identical glass circle, so the row reads as one family.
    @ViewBuilder
    private func slot(_ symbol: LoreSymbol,
                      _ action: @escaping () -> Void) -> some View {
        if symbol == .share, let postcard {
            ShareLink(item:    postcard,
                      subject: Text(title),
                      message: Text(postcard.message),
                      preview: SharePreview(title)) {
                CircleIconLabel(symbol: symbol)
            }
            .buttonStyle(.plain)
        } else {
            CircleIconButton(symbol: symbol, action: action)
        }
    }
}

#if DEBUG
#Preview("Detail header") {
    DetailHeader(title: "Betelgeuse",
                 subtitle: "Star · Orion",
                 accent: .orange,
                 icon: { EmptyView() },
                 leadingSymbol: .share,
                 onLeading: {},
                 onDismiss: {})
        .padding(.bottom, 40)
        .background(.thinMaterial)
}
#endif

import SwiftUI
import LoreKit

// MARK: - DetailHeader
// Apple-Maps place-card-style header used by every detail view in the
// bottom-third sheet.
//
//   [leading] [secondary?]    TITLE        [xmark]
//                            subtitle
//                             [icon]
//
// Leading button is parameterised (`leadingSymbol` + `onLeading`) so
// different detail surfaces can use it for different jobs — share for
// constellation / planet today, back-chevron for star (which can be
// reached via a push from the constellation roster, so it needs an
// affordance to pop).
//
// An optional secondary leading button sits to the right of the
// primary — star detail uses this slot for the share placeholder so
// it can have *both* the chevron and the share button without
// crowding the trailing side. X-mark (top-trailing) dismisses the
// sheet via the host's closure.
//
// The icon below the subtitle is a small category cue (`POIBadgeView`
// for stars / planets, an SF Symbol for constellations) so the header
// reads as part of the same visual species as the canvas POI.
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
         onDismiss:              @escaping () -> Void) {
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
        ZStack(alignment: .top) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !collapsed && title == Strings.Bodies.moon {
                    icon
                        .font(.subheadline)
                        .foregroundStyle(accent)
                        .padding(.top, 4)
                }
            }
            // Padding scales with whether the secondary leading slot
            // is occupied — keeps the title centred in the available
            // horizontal space rather than drifting toward the X.
//            .padding(.horizontal, secondaryLeadingSymbol == nil ? 56 : 100)
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                slot(leadingSymbol, onLeading)
                if let sym = secondaryLeadingSymbol,
                   let act = onSecondaryLeading {
                    slot(sym, act)
                }
                Spacer()

                CircleIconButton(symbol: .xmark, action: onDismiss)
            }
            .padding(.horizontal, 10)
        }
        .padding(.top, 16)
        .padding(.horizontal, 6)
        .padding(.bottom, 8)
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

import SwiftUI

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
    let title:                  String
    let subtitle:               String
    let accent:                 Color
    let icon:                   Icon
    let leadingSymbol:          String
    let onLeading:              () -> Void
    let secondaryLeadingSymbol: String?
    let onSecondaryLeading:     (() -> Void)?
    let onDismiss:              () -> Void

    init(title:                  String,
         subtitle:               String,
         accent:                 Color,
         @ViewBuilder icon:      () -> Icon,
         leadingSymbol:          String,
         onLeading:              @escaping () -> Void,
         secondaryLeadingSymbol: String?           = nil,
         onSecondaryLeading:     (() -> Void)?     = nil,
         onDismiss:              @escaping () -> Void) {
        self.title                  = title
        self.subtitle               = subtitle
        self.accent                 = accent
        self.icon                   = icon()
        self.leadingSymbol          = leadingSymbol
        self.onLeading              = onLeading
        self.secondaryLeadingSymbol = secondaryLeadingSymbol
        self.onSecondaryLeading     = onSecondaryLeading
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
                icon
                    .font(.subheadline)
                    .foregroundStyle(accent)
                    .padding(.top, 4)
            }
            // Padding scales with whether the secondary leading slot
            // is occupied — keeps the title centred in the available
            // horizontal space rather than drifting toward the X.
            .padding(.horizontal, secondaryLeadingSymbol == nil ? 56 : 100)
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                CircleIconButton(systemName: leadingSymbol, action: onLeading)
                if let sym = secondaryLeadingSymbol,
                   let act = onSecondaryLeading {
                    CircleIconButton(systemName: sym, action: act)
                }
                Spacer()
                CircleIconButton(systemName: "xmark", action: onDismiss)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - CircleIconButton
// Small circular toolbar button matching the Apple-Maps place-card
// idiom — tinted glass / system fill with a centred SF Symbol.
private struct CircleIconButton: View {
    let systemName: String
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Color(.tertiarySystemFill), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

// MARK: - DetailHeader
// Apple-Maps place-card-style header used by every detail view in the
// bottom-third sheet.
//
//   [leading]      TITLE        [xmark]
//                 subtitle
//                  [icon]
//
// Leading button is parameterised (`leadingSymbol` + `onLeading`) so
// different detail surfaces can use it for different jobs — share for
// constellation / planet today, back-chevron for star (which can be
// reached via a push from the constellation roster, so it needs an
// affordance to pop). X-mark (top-trailing) dismisses the sheet via
// the host's closure.
//
// The icon below the subtitle is a small category cue (`POIBadgeView`
// for stars / planets, an SF Symbol for constellations) so the header
// reads as part of the same visual species as the canvas POI.
struct DetailHeader<Icon: View>: View {
    let title:         String
    let subtitle:      String
    let accent:        Color
    let icon:          Icon
    let leadingSymbol: String
    let onLeading:     () -> Void
    let onDismiss:     () -> Void

    init(title:         String,
         subtitle:      String,
         accent:        Color,
         @ViewBuilder icon: () -> Icon,
         leadingSymbol: String,
         onLeading:     @escaping () -> Void,
         onDismiss:     @escaping () -> Void) {
        self.title         = title
        self.subtitle      = subtitle
        self.accent        = accent
        self.icon          = icon()
        self.leadingSymbol = leadingSymbol
        self.onLeading     = onLeading
        self.onDismiss     = onDismiss
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
            .padding(.horizontal, 56)         // leave room for the side buttons
            .frame(maxWidth: .infinity)

            HStack {
                CircleIconButton(systemName: leadingSymbol, action: onLeading)
                Spacer()
                CircleIconButton(systemName: "xmark",       action: onDismiss)
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

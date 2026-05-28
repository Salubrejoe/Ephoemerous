import SwiftUI

// MARK: - DetailHeader
// Apple-Maps place-card-style header used by every detail view in the
// bottom-third sheet.
//
//   [share]        TITLE        [xmark]
//                 subtitle
//                  [icon]
//
// Share button (top-leading) is wired but currently no-ops — the
// system share sheet for sky-object IDs will come later. X-mark
// (top-trailing) dismisses via the host's closure. The icon below
// the subtitle is a small category cue (star symbol, constellation
// entity glyph, planet sigil) tinted to the same accent as the
// object's badge so the header reads as part of the same visual
// species as the canvas POI.
struct DetailHeader<Icon: View>: View {
    let title:     String
    let subtitle:  String
    let accent:    Color
    let icon:      Icon
    let onShare:   () -> Void
    let onDismiss: () -> Void

    init(title:    String,
         subtitle: String,
         accent:   Color,
         @ViewBuilder icon: () -> Icon,
         onShare:   @escaping () -> Void,
         onDismiss: @escaping () -> Void) {
        self.title     = title
        self.subtitle  = subtitle
        self.accent    = accent
        self.icon      = icon()
        self.onShare   = onShare
        self.onDismiss = onDismiss
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
                CircleIconButton(systemName: "square.and.arrow.up", action: onShare)
                Spacer()
                CircleIconButton(systemName: "xmark",                action: onDismiss)
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

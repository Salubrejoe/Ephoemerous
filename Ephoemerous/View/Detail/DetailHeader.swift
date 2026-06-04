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
    let leadingSymbol:          String
    let onLeading:              () -> Void
    let secondaryLeadingSymbol: String?
    let onSecondaryLeading:     (() -> Void)?
    let onNow:                  (() -> Void)?
    let nowIsActive:            Bool
    let onDismiss:              () -> Void

    init(title:                  String,
         subtitle:               String,
         accent:                 Color,
         @ViewBuilder icon:      () -> Icon,
         leadingSymbol:          String,
         onLeading:              @escaping () -> Void,
         secondaryLeadingSymbol: String?           = nil,
         onSecondaryLeading:     (() -> Void)?     = nil,
         onNow:                  (() -> Void)?     = nil,
         nowIsActive:            Bool              = false,
         onDismiss:              @escaping () -> Void) {
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
                    .fontDesign(.serif)            // sky-object name → serif
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !collapsed {
                    icon
                        .font(.subheadline)
                        .foregroundStyle(accent)
                        .padding(.top, 4)
                }
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
                
                CircleIconButton(systemName: "xmark.circle.fill", action: onDismiss)
            }
            .padding(.horizontal, 10)
        }
        .padding(.top, 16)
        .padding(.horizontal, 6)
        .padding(.bottom, 8)
    }
}

// MARK: - CircleIconButton
// Small circular toolbar button — Liquid-Glass capsule with a
// centred SF Symbol. Matches the canvas-toolbar buttons (Image-
// magnitudeIcon, etc.) so the header reads as part of the same
// chrome system.
private struct CircleIconButton: View {
    let systemName: String
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NowPillButton
// "Now" shortcut — same glass capsule + Label idiom the
// DatePickerPanel toolbar uses for its own Now action, so the two
// surfaces feel like the same gesture. Tap commits whatever the
// caller wants (e.g. `state.observationDate = .now`).
//
// `isDisabled` greys the pill out and blocks taps when the
// observation date is already at real-world now — no point firing
// the same gesture twice.
private struct NowPillButton: View {
    let action:     () -> Void
    let isDisabled: Bool

    var body: some View {
        Button(action: action) {
            Label("Now", symbol: .clockFill)
                .font(.callout.weight(.medium))
                .foregroundStyle(isDisabled ? .secondary : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical,    9)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: .capsule)
        .opacity(isDisabled ? 0.55 : 1.0)
        .disabled(isDisabled)
    }
}

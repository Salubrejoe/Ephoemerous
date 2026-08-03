import SwiftUI
import LoreKit

// MARK: - RememberButton
// The Remember (favourite) action for an object with NO paired
// secondary action — i.e. a star / constellation with no myth cycle to
// "Learn" (Lacaille / Bayer / Hevelius and the stars in them). It's the
// `myth == .none` branch of `DetailActionRow`.
//
// Deliberately RECEDED, not a primary CTA: a star with no story behind
// it has less reason to shout, so this is a quiet full-width capsule on
// regular material with an accent-tinted heart + label — secondary
// hierarchy, "available, not demanding". (A star that IS part of a myth
// gets the prominent paired Remember in DetailActionRow instead.) Same
// height + capsule shape as the paired row so the layout never twitches
// between the two cases.
//
// "Remember" is the in-UI verb for what the codebase calls a favourite —
// softer than "follow", matching the app's mnemonic voice. State-bound
// to `AppState.isFavourite(obj)`; toggles via `toggleFavourite(obj)`.
// Works for any SkyObject case.
struct RememberButton: View {
    @Environment(AppState.self) var state
    let obj: SkyObject

    /// Same fixed height the paired DetailActionRow pills use, so the
    /// row keeps a constant height whether or not the object has a myth.
    private let pillHeight: CGFloat = 50

    var body: some View {
        let remembered = state.isFavourite(obj)
        Button {
            state.toggleFavourite(obj)
        } label: {
            HStack(spacing: 8) {
                Image(symbol: remembered ? .heartFill : .heart)
                    .foregroundStyle(remembered ? .pink : .primary)
                Text(remembered ? String(localized: "Remembered") : String(localized: "Remember"))
                    .fontWeight(.semibold)
            }
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: pillHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(remembered ? .clear : .accentColor).interactive(), in: .capsule)
        .animation(.bouncy, value: remembered)
    }
}

#if DEBUG
#Preview("Remember") {
    RememberButton(obj: .star(PreviewSky.someStar))
        .environment(AppState())
        .padding()
}
#endif

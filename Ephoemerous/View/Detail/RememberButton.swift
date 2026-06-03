import SwiftUI

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
// to `EAppState.isFavourite(obj)`; toggles via `toggleFavourite(obj)`.
// Works for any ESkyObject case.
struct RememberButton: View {
    @Environment(EAppState.self) var state
    let obj: ESkyObject

    /// Same fixed height the paired DetailActionRow pills use, so the
    /// row keeps a constant height whether or not the object has a myth.
    private let pillHeight: CGFloat = 50

    var body: some View {
        let remembered = state.isFavourite(obj)
        Button {
            state.toggleFavourite(obj)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: remembered ? "heart.fill" : "heart")
                Text(remembered ? "Remembered" : "Remember")
                    .fontWeight(.semibold)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .frame(height: pillHeight)
            .background(.regularMaterial, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

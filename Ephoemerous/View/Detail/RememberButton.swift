import SwiftUI

// MARK: - RememberButton
// Big prominent blue button sitting just below the DetailHeader —
// the Apple-Maps "Directions" button slot, repurposed as the
// primary action for any sky object: Remember (favourite) or
// Forget (un-favourite). "Remember" is the in-UI verb for what
// the codebase calls a favourite — softer than "follow", matches
// the app's mnemonic voice.
//
// State-bound to `EAppState.isFavourite(obj)`; toggles via
// `EAppState.toggleFavourite(obj)`. Works for any ESkyObject case
// even before that category's UI is exposed — the data structure
// is universal.
struct RememberButton: View {
    @Environment(EAppState.self) var state
    let obj: ESkyObject

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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor, in: Capsule(style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

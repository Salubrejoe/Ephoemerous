import SwiftUI
import LoreKit

// MARK: - FavoriteCircleButton
// The favourite toggle at the trailing end of a star's or constellation's
// title: a material circle holding just the heart. Empty, it's quiet ink;
// tapped, the symbol swaps to the filled heart and bounces, turning
// systemPink, with a success tap under the finger.
struct FavoriteCircleButton: View {

    @Environment(AppState.self) private var state

    let obj: SkyObject

    private let diameter: CGFloat = 40

    private var isFavorite: Bool { state.isFavourite(obj) }

    var body: some View {
        Button { state.toggleFavourite(obj) } label: {
            Image(symbol: isFavorite ? .heartFill : .heart)
                .font(.body.weight(.semibold))
                .foregroundStyle(isFavorite ? Color.pink : .primary)            // systemPink
                .contentTransition(.symbolEffect(.replace.downUp))
                .symbolEffect(.bounce, value: isFavorite)
                .frame(width: diameter, height: diameter)
                .background(.regularMaterial, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: isFavorite) { _, now in now }
        .accessibilityLabel(isFavorite ? String(localized: "Favorited") : String(localized: "Favorite"))
    }
}

import SwiftUI
import LoreKit

// MARK: - FavoriteCircleButton
// The Pin toggle at the trailing end of a star's or constellation's title:
// a material circle holding just the pin. Unpinned, it's quiet ink; tapped,
// the symbol swaps to the filled pin and bounces, turning the accent — the
// app's one "engaged" colour — with a success tap under the finger.
struct FavoriteCircleButton: View {

    @Environment(AppState.self) private var state

    let obj: SkyObject

    private let diameter: CGFloat = 40

    private var isFavorite: Bool { state.isFavourite(obj) }

    var body: some View {
        Button { state.toggleFavourite(obj) } label: {
            Image(systemName: isFavorite ? "pin.fill" : "pin")
                .font(.body.weight(.semibold))
                .foregroundStyle(isFavorite ? Color.accentColor : .primary)
                .contentTransition(.symbolEffect(.replace.downUp))
                .symbolEffect(.bounce, value: isFavorite)
                .frame(width: diameter, height: diameter)
                .background(.regularMaterial, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: isFavorite) { _, now in now }
        .accessibilityLabel(isFavorite ? String(localized: "Pinned") : String(localized: "Pin"))
    }
}

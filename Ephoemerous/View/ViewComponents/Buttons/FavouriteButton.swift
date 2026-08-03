
import SwiftUI
import LoreKit

// MARK: - FavouriteButton
// Toggles `obj`'s membership in `state.favourites`. Star-shaped today
// since stars are the only category currently surfaced as favourites
// in detail views — when sun / moon / planet / constellation get their
// own favourite affordance the button is already generic.
//
// The accent only specialises for stars (spectral class). Other
// categories fall back to `.primary` until their detail UI lights up.
struct FavouriteButton: View {
    @Environment(AppState.self) var state
    let obj: SkyObject

    init(obj: SkyObject) {
        self.obj = obj
    }

    /// Convenience for the common star call site — keeps usage as
    /// `FavouriteButton(star: …)` legible even though the canonical
    /// form is `FavouriteButton(obj: .star(…))`.
    init(star: Star) {
        self.obj = .star(star)
    }

    var body: some View {
        let isFav = state.isFavourite(obj)
        Button {
            state.toggleFavourite(obj)
        } label: {
            Image(symbol: isFav ? .target : .circle)
                .resizable()
                .scaledToFit()
                .frame(width: 33, height: 33)
                .shadow(color: isFav ? tint : .clear, radius: 5)
        }
        .foregroundStyle(isFav ? tint : tint.opacity(0.3))
    }

    private var tint: Color {
        if case .star(let s) = obj { return s.spectralClass.color }
        return .primary
    }
}

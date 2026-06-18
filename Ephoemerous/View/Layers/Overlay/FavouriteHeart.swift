import SwiftUI
import simd

// MARK: - SkyLabFavouritesOverlay
// The favourite SIGNAL on stars — a small always-visible heart in the
// star's spectral-class colour, so a followed star reads as favourited at
// any zoom (the `.followedStar` POI label still adds the badge + name when
// you zoom in). Native, constant screen size (counter-scaled), positioned
// via the shared camera.
struct FavouriteHeart: View {

    let camera: SkyCamera
    let stars:  [EStar]
    let pinch:  CGFloat
    /// Live map rotation — counter-rotated so the heart stays upright while
    /// the sky spins (Apple-Maps).
    var rotation: Angle = .zero
    /// Selected star is shown by the promoted pin instead — skip its heart
    /// so a highlighted favourite isn't drawn twice (pin + heart).
    var selectedID: UUID? = nil

    var body: some View {
        ZStack {
            ForEach(marks) { mark in
                Image(systemName: "suit.heart.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(mark.color)
                    .shadow(color: .black.opacity(0.4), radius: 1.5)
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    // Top-leading of the star so it reads as a corner mark
                    // once the badge appears.
                    .position(x: mark.sc.x - 5, y: mark.sc.y - 5)
            }
        }
    }

    private struct Mark: Identifiable {
        let id:    UUID
        let sc:    CGPoint
        let color: Color
    }

    private var marks: [Mark] {
        let w = camera.size.width, h = camera.size.height
        return stars.compactMap { star in
            guard star.id != selectedID else { return nil }    // shown as the promoted pin
            guard let sc = camera.screen(equatorial: star.equatorialVector) else { return nil }
            guard sc.x > -20, sc.x < w + 20, sc.y > -20, sc.y < h + 20 else { return nil }
            return Mark(id: star.id, sc: sc, color: star.spectralClass.color)
        }
    }
}

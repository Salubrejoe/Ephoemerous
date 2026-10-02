import SwiftUI

// MARK: - BayerLabels
// The bare Greek letter on a figure star that has no name of its own.
//
// A constellation's stick-figure reaches a couple of dozen stars, and only
// a handful of them are called anything — Betelgeuse, Rigel, Bellatrix.
// The rest are α, β, γ … and until now the figure drew a line to a dot the
// map never identified. This letters them, and only them:
//
//   • touched by a stick-figure segment  (`ConstellationLines.figureStars`)
//   • no proper name                     (one mark per star — a named star
//                                         already gets its full POI label)
//   • carrying a Bayer letter            (Flamsteed-only stars stay mute;
//                                         "42" is a catalogue row, not a
//                                         name, and reads as clutter)
//
// It is the QUIETEST voice on the map — a whisper, in the rulebook's terms
// (cartography whispers, labels speak, the selection announces). No badge,
// no casing, no heart, no tap: the letter is an annotation on a dot that is
// already drawn, not a thing you can pick. `MainView+Selection` builds its
// tap candidates from favourites and proper-named stars only, so these are
// unreachable by touch by construction — `allowsHitTesting(false)` says so
// out loud rather than leaving it to be inferred.
//
// Culled to the oversized canvas, counter-rotated so the glyph stays
// screen-upright while the sky spins, counter-scaled `1/pinch` to hold a
// constant screen size — the same contract every other label layer signs.
struct BayerLabels: View {

    let camera: SkyCamera
    let stars:  [Star]
    let pinch:  CGFloat
    let scale:  CGFloat
    /// Live map rotation — counter-rotated per glyph (Apple-Maps).
    var rotation: Angle = .zero
    /// The selected star is drawn by the promoted pin instead. A letterless
    /// star can't be tapped, but it CAN arrive selected from search, so the
    /// guard is real.
    var selectedID: String? = nil
    /// Letters fade outside the calm middle of the screen.
    var comfort: LabelComfortZone = .everywhere

    /// One flat threshold for the whole layer — see `Artist.bayerLetterIn`.
    private static let letterIn: Double = Artist.shared.bayerLetterIn

    /// Max blur (pt) at reveal 0, matching the other label layers: the
    /// glyph resolves out of a soft haze rather than switching on.
    private static let blur: CGFloat = 4

    /// Top-trailing corner offset (pt) from the star, so the letter annotates
    /// the dot instead of covering it. Baked into the position in canvas
    /// space, the way `FavouriteHeart` corners its heart. ▼ TWEAK ▼
    private static let corner = CGPoint(x: 7, y: -7)

    var body: some View {
        ZStack {
            ForEach(marks) { mark in
                // Bayer designations are set in italic serif by every star
                // atlas since 1603; the map may as well keep the habit.
                Text(mark.letter)
                    .font(.caption2)
                    .fontDesign(.serif)
                    .italic()
                    .foregroundStyle(.secondary)
                    .opacity(mark.reveal)
                    .blur(radius: (1 - mark.reveal) * Self.blur)
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    .position(x: mark.sc.x + Self.corner.x,
                              y: mark.sc.y + Self.corner.y)
            }
        }
        // Annotation, not a target. See the note above.
        .allowsHitTesting(false)
    }

    private struct Mark: Identifiable {
        let id:     String
        let letter: String
        let sc:     CGPoint
        let reveal: Double
    }

    private var marks: [Mark] {
        // Every glyph shares one threshold, so the reveal is computed ONCE
        // and the layer early-outs entirely below it — nothing projected,
        // nothing rendered, until you are zoomed into letter territory.
        let reveal = POILabelView.tierReveal(scale: scale, threshold: Self.letterIn)
        guard reveal > 0.01 else { return [] }

        let w = camera.size.width, h = camera.size.height
        return stars.compactMap { star in
            guard star.id != selectedID else { return nil }         // promoted elsewhere
            guard let letter = star.bayerLetter else { return nil }
            guard let sc = camera.screen(equatorial: star.equatorialVector) else { return nil }
            guard sc.x > -40, sc.x < w + 40, sc.y > -40, sc.y < h + 40 else { return nil }
            let calm = comfort.nameVisibility(at: sc)
            guard calm > 0.01 else { return nil }
            return Mark(id: star.id, letter: letter, sc: sc, reveal: reveal * calm)
        }
    }
}

#if DEBUG
#Preview("Bayer letters") {
    PreviewSky.night {
        BayerLabels(camera: PreviewSky.camera,
                    stars: SkyFrame.bayerFigureStars,
                    pinch: 1, scale: 600, rotation: .zero,
                    selectedID: nil)
    }
}
#endif

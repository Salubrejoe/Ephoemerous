import SwiftUI
import LoreKit
// `\.widgetRenderingMode` is read below; MEMBER_IMPORT_VISIBILITY is on for
// this project, so the defining module must be imported explicitly.
import WidgetKit

// MARK: - FavouriteHeartMark
// The Remembered heart, wearing the same clothes as every other POI mark:
// a vertical gradient body and the shared dark casing.
//
// It used to be a plain `Image(systemName:)` in a flat tint — the only mark
// on the canvas NOT speaking the badge grammar, which is why it read as
// pasted on rather than part of the family. `SFSymbolShape` (LoreKit) gives
// us the glyph as a real `Shape`, so it can be filled AND stroked exactly
// like a badge.
//
// One definition, two mounts: the field hearts (`FavouriteHeart`) and the
// promoted pin's corner heart (`PromotedLabel`) — so the pink voice can
// never drift between them.
struct FavouriteHeartMark: View {

    /// Glyph size in points.
    var size: CGFloat = 12
    /// Inverse of any `.scaleEffect` the caller wraps this in, so the casing
    /// keeps a constant weight while the heart grows — same contract as
    /// `POILabelView.borderScaleCompensation`.
    var borderScaleCompensation: CGFloat = 1

    /// Tinted / "Clear" widget themes repaint every pixel, so the casing
    /// would come back white and smear the glyph. Same rule as the badges.
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    private var isMasked: Bool { widgetRenderingMode != .fullColor }

    // ▼ TWEAK the heart's colours here ▼
    // Bottom → top, matching the badge orbs' lighting.
    static let deep   = Color(red: 0.86, green: 0.18, blue: 0.36)
    static let bright = Color(red: 1.00, green: 0.48, blue: 0.60)

    private var heart: SFSymbolShape {
        SFSymbolShape(systemName: "suit.heart.fill", weight: .bold)
    }

    var body: some View {
        let bw = Artist.shared.poiTextBorderWidth * borderScaleCompensation * 0.7

        heart
            .fill(LinearGradient(colors: [Self.deep, Self.bright],
                                 startPoint: .bottom, endPoint: .top))
            .overlay {
                heart.stroke(isMasked ? .clear : Artist.shared.poiBadgeCasing,
                             lineWidth: bw)
            }
            .frame(width: size, height: size)
            .shadow(color: isMasked ? .clear : .black.opacity(0.35),
                    radius: isMasked ? 0 : 1.5)
    }
}

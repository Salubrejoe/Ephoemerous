import SwiftUI

// MARK: - Favourite cards
// Compact 110-pt cards used by:
//   • EConstellationDetailView's star roster
//   • The new SearchSheet's horizontal favourites scroll
//
// Two species today — `StarCard` and `ConstellationCard` — share an
// internal slot grid (icon 24, name 22, subtitle 14) and a
// `tertiarySystemFill` rounded-rect background so they read as the
// same visual family in a mixed scroll.

// MARK: StarCard

/// One figure-star, rendered as a card. The badge uses the
/// followed-star POI style so the spectral pentagon + glyph match
/// the canvas. Wrap in a `NavigationLink`-or-tap-handler at the
/// callsite.
struct StarCard: View {
    let star: EStar

    var body: some View {
        VStack(spacing: 6) {
            POILabelView(category: .followedStar(star), glyph: .sfSymbol(""), text: "", labelStyle: .star)
//            POIBadgeView(category: .followedStar(star), size: 24)
                .frame(height: 24)
            Text(star.displayName)
                .font(.title3.weight(.semibold))
                .fontDesign(.serif)            // sky-object name → serif
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 22)
            Text(String(format: "%.1f mag", star.magnitude))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(height: 14)
        }
        .frame(width: 110)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 14)
        .background(Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: ConstellationCard

/// One constellation, rendered as a card. Mirrors `StarCard` —
/// entity SF Symbol tinted with the myth gradient's top color in
/// the icon slot, full name in the name slot, entity/myth descriptor
/// in the subtitle slot.
struct ConstellationCard: View {
    @Environment(EAppState.self) private var state
    let constellation: EConstellation

    private var artist: EArtist { EArtist.shared }

    private var iconSymbol: ESymbol {
        artist.constellationEntitySymbol(
            artist.constellationEntity(of: constellation)
        )
    }

    /// Same accent the constellation's POI badge uses on the canvas —
    /// top of the myth gradient. Falls back gracefully when the
    /// constellation is in the `.foreverInvisible` band by reading the
    /// kind for the current observer latitude.
    private var accent: Color {
        let kind = artist.constellationKind(
            constellation,
            decDegrees:       0,
            observerLatitude: state.origin.latitude.degrees
        )
        return artist.constellationGradient(kind: kind).top
    }

    /// Short subtitle: entity name, or "Constellation" if the
    /// constellation has no entity classification (Lacaille /
    /// Bayer / Hevelius modern additions).
    private var subtitle: String {
        artist.constellationEntity(of: constellation).localizedName
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(symbol: iconSymbol)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(height: 24)
            Text(constellation.localizedName)
                .font(.title3.weight(.semibold))
                .fontDesign(.serif)            // sky-object name → serif
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 22)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)
                .frame(height: 14)
        }
        .frame(width: 110)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 14)
        .background(Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

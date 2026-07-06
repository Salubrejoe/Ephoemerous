import SwiftUI
import LoreKit

// MARK: - EStarDetailView
// Three-tile compact star detail. Fits the bottom-third sheet detent
// without scrolling: header + Remember button + a single HStack of
// Class / Distance / Magnitude tiles. SF Symbols carry the meaning;
// negative space carries the calm.

struct EStarDetailView: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss
    @Environment(\.detailCollapsed) private var collapsed
    let star: EStar
    /// `true` only when the view is pushed onto a navigation stack
    /// that has a sensible parent to pop back to — currently only
    /// the constellation roster's `navigationDestination`. When
    /// reached as a root detail sheet (canvas tap or search-sheet
    /// open), the back chevron has nowhere to go, so the share
    /// button takes the primary-leading slot instead.
    var showsBackChevron: Bool = false

    private var accent: Color { star.spectralClass.color }

    /// `Bayer designation · Constellation full name`, e.g.
    /// "α · Orion". For unnamed stars (display name *is* the Bayer
    /// designation) we skip the letter to avoid the title and subtitle
    /// both leading with the same character.
    private var subtitleText: String {
        guard star.properName != nil else { return star.constellation.localizedName }
        let letter = star.name.split(separator: " ").first.map(String.init) ?? ""
        return letter.isEmpty
            ? star.constellation.localizedName
            : "\(letter) · \(star.constellation.localizedName)"
    }

    /// A star inherits its myth from its parent constellation —
    /// Betelgeuse is "in" the Orion cycle because Orion is. `.none`
    /// for stars in modern (Lacaille / Bayer / Hevelius)
    /// constellations; DetailActionRow's `.none` path then renders
    /// the bare RememberButton instead of the morphing pair.
    private var myth: POIConstellationMyth {
        EArtist.shared.constellationMyth(of: star.constellation)
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:                  star.displayName,
                subtitle:               subtitleText,
                accent:                 accent,
                icon:                   {
                    POILabelView(
                        category: .followedStar(star),
                        glyph: .sfSymbol("star.fill"),
                        text: "",
                        labelStyle: .star
                    )
                },
                leadingSymbol:          showsBackChevron ? .chevronBackward : .share,
                onLeading:              { showsBackChevron ? dismiss() : () },
                secondaryLeadingSymbol: showsBackChevron ? .share : nil,
                onSecondaryLeading:     showsBackChevron ? {} : nil,
                onDismiss:              { state.dismissDetail() }
            )
            if !collapsed {
                // Morphing action row — see `DetailActionRow.swift`.
                // Same pair as the constellation detail; the star's
                // myth is inherited from its parent constellation, and
                // tapping the book / tagline routes through
                // `state.openMyth(_:)` for the half-detent myth sheet.
                DetailActionRow(obj: .star(star))
                .padding(.horizontal, 16)
                .padding(.bottom,     12)
                
                
                DetailHScrollView(stats: [
                    .init(value: distanceText,                statType: .distance),
                    .init(value: star.spectralClass.rawValue, statType: .hrClass),
                    .init(value: magnitudeText,               statType: .magnitude),
                    .init(value: raText,                      statType: .rightAscenscion),
                    .init(value: decText,                     statType: .declination),
                ])
                .padding(.top, 16)
            }
            Spacer(minLength: 0)
        }
        // Hide the system NavigationStack chrome on this view
        // specifically. DetailHost already hides the bar for the
        // *root* view of the stack, but pushed destinations (this
        // view, when reached from a constellation card) get their
        // own bar back unless they suppress it themselves.
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Universal Recents entry — covers the push-from-constellation
            // path that doesn't go through `focus(on:)`.
            state.recordViewed(.star(star))
        }
    }

   
    private var statsRow: some View {
        HStack(spacing: 8) {
            VStack(spacing: 0) {
                DetailTile(icon:  "thermometer.medium",
                     value: star.spectralClass.rawValue)
                DetailTile(icon:  "ruler",
                     value: distanceText)
            }
            
            VStack(spacing: 0) {
                DetailTile(icon:  "eyes",
                     value: magnitudeText)

                DetailTile(icon:  "clock",
                     value: raText)
            }
        }
        .overlay {
            Rectangle()
                .frame(maxWidth: .infinity)
                .frame(height: 1)
            
            Rectangle()
                .frame(maxHeight: .infinity)
                .frame(width: 1)
        }
    }


    // MARK: Value formatting

    private var distanceText: String {
        guard let ly = star.distanceLY else { return "—" }
        return ly >= 100
            ? "\(Int(ly)) ly"
            : String(format: "%.1f ly", ly)
    }

    private var magnitudeText: String {
        String(format: "%.1f", star.magnitude)
    }
    
    private var raText: String {
        String(format: "%.1f", star.rightAscension.degrees)
    }
    
    private var decText: String {
        String(format: "%.1f", star.declination.degrees)
    }

    // MARK: Glow

    @ViewBuilder
    private func glowBackground() -> some View {
        ZStack {
            Circle()
                .fill(state.isFavouriteStar(star) ? star.spectralClass.color : .clear)
                .frame(width: 33, height: 33)
                .blur(radius: 30)
                .padding(25)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EStarDetailView(star: EStar.mockStars[0])
    }
    .environment(EAppState())
}

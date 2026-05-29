import SwiftUI

// MARK: - EStarDetailView
// Three-tile compact star detail. Fits the bottom-third sheet detent
// without scrolling: header + Remember button + a single HStack of
// Class / Distance / Magnitude tiles. SF Symbols carry the meaning;
// negative space carries the calm.

struct EStarDetailView: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss
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
        guard star.properName != nil else { return star.constellation.fullName }
        let letter = star.name.split(separator: " ").first.map(String.init) ?? ""
        return letter.isEmpty
            ? star.constellation.fullName
            : "\(letter) · \(star.constellation.fullName)"
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
                icon:                   { POIBadgeView(category: .followedStar(star)) },
                leadingSymbol:          showsBackChevron ? "chevron.backward" : "square.and.arrow.up",
                onLeading:              { showsBackChevron ? dismiss() : () },
                secondaryLeadingSymbol: showsBackChevron ? "square.and.arrow.up" : nil,
                onSecondaryLeading:     showsBackChevron ? {} : nil,
                onDismiss:              { state.dismissDetail() }
            )
            // Morphing action row — see `DetailActionRow.swift`.
            // Same pair as the constellation detail; the star's
            // myth is inherited from its parent constellation, and
            // tapping the book / tagline routes through
            // `state.openMyth(_:)` for the half-detent myth sheet.
            DetailActionRow(
                obj:         .star(star),
                myth:        myth,
                onLearnMyth: { state.openMyth(myth) }
            )
            .padding(.horizontal, 16)
            .padding(.bottom,     12)
            statsRow
                .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .background(glowBackground())
        // Hide the system NavigationStack chrome on this view
        // specifically. DetailHost already hides the bar for the
        // *root* view of the stack, but pushed destinations (this
        // view, when reached from a constellation card) get their
        // own bar back unless they suppress it themselves.
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Pan the canvas to this star whether we arrived here via
            // canvas-tap (focus already panned — this is a harmless
            // re-pan to the same point) or via a push from a
            // constellation card (only trigger). Also captures the
            // star as a recently-viewed item regardless of entry path
            // (the navigationDestination wrapper used to do this for
            // the constellation-push case only).
            state.panTo(.star(star))
            state.recordViewed(star)
        }
    }

    // MARK: Stats row

    /// Fixed row height — every tile fills this exactly, guaranteeing
    /// the three backgrounds line up regardless of which SF Symbol
    /// happens to render slightly shorter than the others. Bump if
    /// the content needs more breathing room.
    private var statsRowHeight: CGFloat { 100 }

    /// Three equal-width SF-Symbol tiles. The Class tile picks up
    /// the spectral accent so the star's colour shows up exactly
    /// once on the canvas-of-the-detail; the other two tiles stay
    /// neutral so the eye doesn't get pulled three ways at once.
    private var statsRow: some View {
        HStack(spacing: 8) {
            tile(icon:     "thermometer.medium",
                 iconTint: accent,
                 value:    star.spectralClass.rawValue,
                 label:    "Class")
            tile(icon:     "ruler",
                 iconTint: .secondary,
                 value:    distanceText,
                 label:    "Distance")
            tile(icon:     "sparkles",
                 iconTint: .secondary,
                 value:    magnitudeText,
                 label:    "Magnitude")
        }
        .frame(height: statsRowHeight)
    }

    private func tile(icon: String, iconTint: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            // Fixed-height slot for the icon so the value + label
            // rows below land at the same baseline across all three
            // tiles regardless of the SF Symbol's intrinsic height
            // (thermometer tall, ruler short, sparkles medium).
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconTint)
                .frame(height: 24)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .monospacedDigit()
                .frame(height: 22)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 14)
        .background(Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

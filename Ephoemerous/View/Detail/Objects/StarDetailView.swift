import SwiftUI
import LoreKit

// MARK: - StarDetailView
// Three-tile compact star detail. Fits the bottom-third sheet detent
// without scrolling: header + Remember button + a single HStack of
// Class / Distance / Magnitude tiles. SF Symbols carry the meaning;
// negative space carries the calm.

struct StarDetailView: View {
    @Environment(AppState.self) var state
    @Environment(\.dismiss) var dismiss
    @Environment(\.detailCollapsed) private var collapsed
    let star: Star
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

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:                  star.displayName,
                subtitle:               subtitleText,
                accent:                 accent,
                icon:                   {
                    POILabelView(
                        category: .followedStar(star),
                        text: "",
                        labelStyle: .star
                    )
                },
                leadingSymbol:          showsBackChevron ? .chevronBackward : .share,
                onLeading:              { showsBackChevron ? dismiss() : () },
                secondaryLeadingSymbol: showsBackChevron ? .share : nil,
                onSecondaryLeading:     showsBackChevron ? {} : nil,
                postcard:               state.postcard(for: .star(star)),
                onDismiss:              { state.dismissDetail() }
            )
            if !collapsed {
                // Morphing Remember row — see `DetailActionRow.swift`.
                DetailActionRow(obj: .star(star))
                .padding(.horizontal, 16)
                .padding(.top,        12)

                DetailStatList(stats: stats)
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


    // MARK: Stat rows

    /// The sheet's rows. Companion facts sit directly under Magnitude —
    /// they qualify how the star LOOKS, so they belong with brightness
    /// rather than after the positional/catalogue tail (RA, Dec, μ).
    private var stats: [DetailStat] {
        [
            .init(label: String(localized: "Distance"),        value: distanceText),
            .init(label: String(localized: "Spectral class"),  value: star.spectralClass.rawValue),
            .init(label: String(localized: "Magnitude"),       value: magnitudeText),
        ]
        + companionStats
        + [
            .init(label: String(localized: "Right ascension"), value: raText),
            .init(label: String(localized: "Declination"),     value: decText),
            .init(label: String(localized: "Proper motion"),   value: pmText),
        ]
    }

    /// Companion rows, present ONLY when the catalogue actually knows
    /// something. Every row here is individually optional: BSC5 fills these
    /// columns unevenly, and an empty "Separation —" row is worse than no
    /// row at all. A star with no companion data adds nothing.
    private var companionStats: [DetailStat] {
        guard let m = star.multiplicity else { return [] }
        var rows: [DetailStat] = []

        if let hint = m.observingHint {
            rows.append(.init(label: String(localized: "Companion"), value: hint))
        }
        if let text = separationText(m) {
            rows.append(.init(label: String(localized: "Separation"), value: text))
        }
        if let dm = m.magnitudeDifference, dm > 0 {
            rows.append(.init(label: String(localized: "Brightness gap"),
                              value: String(format: "%.1f mag", dm)))
        }
        if let count = m.componentCount, count > 1 {
            rows.append(.init(label: String(localized: "Components"), value: "\(count)"))
        }
        return rows
    }

    /// Separation, in whichever unit reads without a mental conversion:
    /// arcseconds up to a minute, then arcminutes (Alpheratz's 81.5″ is
    /// easier to picture as 1.4′).
    ///
    /// `0` is NOT "touching" — it is the catalogue's "known multiple, gap
    /// unrecorded", which is why Mizar carries no separation despite being
    /// a 14″ pair. Saying so is more honest than printing 0.0″.
    private func separationText(_ m: StarMultiplicity) -> String? {
        guard let sep = m.separation else { return nil }
        if sep == 0    { return String(localized: "Unresolved") }
        if sep >= 60   { return String(format: "%.1f′", sep / 60) }
        return String(format: "%.1f″", sep)
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
        let hours = star.rightAscension.degrees / 15
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return String(format: "%dh %02dm", h, m)
    }

    private var decText: String {
        String(format: "%+.1f°", star.declination.degrees)
    }

    /// Proper motion in RA / Dec (mas/yr — see `Strings.starDataDetail`).
    private var pmText: String {
        String(format: "%+.1f, %+.1f mas/yr", star.pmRA, star.pmDE)
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

#if DEBUG
#Preview("Star") {
    NavigationStack {
        StarDetailView(star: Star.mockStars[0])
    }
    .environment(AppState())
}

// A real showpiece double, so the companion rows have something to say.
#Preview("Double star") {
    let double = StarDatabase.shared.workableStars
        .first { $0.multiplicity?.isShowpiece == true } ?? Star.mockStars[0]
    return NavigationStack {
        StarDetailView(star: double)
    }
    .environment(AppState())
}
#endif

import SwiftUI

// MARK: - EConstellationDetailView
// Detail sheet for a constellation. Header + Remember button + a
// horizontal scroll of `StarCard`s that each NavigationLink to the
// corresponding `EStarDetailView`. Pushing into a star pans the
// canvas to that star (via the star detail's onAppear); popping
// back re-pans here (via this view's onAppear) — Apple-Maps-style
// "the canvas follows the navigation".

struct EConstellationDetailView: View {
    @Environment(EAppState.self) var state
    @Environment(\.detailCollapsed) private var collapsed
    let constellation: EConstellation

    /// Brightest dozen figure-stars of the constellation, sorted
    /// by apparent magnitude.
    private var stars: [EStar] {
        StarDatabase.shared.workableStars
            .filter { $0.constellation == constellation && $0.name != "Unknown" }
            .sorted { $0.magnitude < $1.magnitude }
    }

    /// "Hero in the Perseus Myth" — entity (what the constellation
    /// depicts) + myth (which cycle it belongs to). The "none" cases
    /// fall back to a sensible plain string so post-Hevelius modern
    /// constellations still get a usable subtitle.
    private var subtitleText: String {
        let artist = EArtist.shared
        let entity = artist.constellationEntity(of: constellation)
        let myth   = artist.constellationMyth(of: constellation)
        let entityStr = entity == .none ? "Constellation" : entity.rawValue.capitalized
        if myth == .none { return entityStr }
        return "\(entityStr) in the \(myth.rawValue.capitalized) Myth"
    }

    /// Top of the myth gradient — same accent used for the canvas badge.
    private var accent: Color {
        let artist = EArtist.shared
        let kind   = artist.constellationKind(constellation,
                                              decDegrees:       0,
                                              observerLatitude: state.origin.latitude.degrees)
        return artist.constellationGradient(kind: kind).top
    }

    /// Entity symbol from the existing POI palette — same SF Symbol
    /// the constellation's POI badge used on the canvas when it
    /// still had a badge.
    private var iconSymbolName: String {
        EArtist.shared.constellationEntitySymbol(
            EArtist.shared.constellationEntity(of: constellation)
        )
    }

    /// Primary mythological cycle this constellation belongs to.
    /// Drives the secondary "Learn the Myth" button leading the
    /// Remember row. `.none` hides the button; the row then
    /// collapses to Remember-only.
    private var myth: POIConstellationMyth {
        EArtist.shared.constellationMyth(of: constellation)
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:         constellation.fullName,
                subtitle:      subtitleText,
                accent:        accent,
                icon:          { Image(systemName: iconSymbolName) },
                leadingSymbol: "square.and.arrow.up",
                onLeading:     {},
                onDismiss:     { state.dismissDetail() }
            )
            if !collapsed {
                // Morphing action row — see `DetailActionRow.swift`.
                // Default: small "book" circle + wide "Remember" pill.
                // Remembered: wide tagline pill + small heart circle.
                // Tapping the book / tagline routes through
                // `state.openMyth(_:)`, which dismisses this detail
                // sheet and presents the half-detent myth sheet.
                DetailActionRow(
                    obj:         .constellation(constellation),
                    myth:        myth,
                    onLearnMyth: { state.openMyth(myth) }
                )
                .padding(.horizontal, 16)
                .padding(.bottom,     12)
                roster
            }
            Spacer(minLength: 0)
        }
        // The constellation is the *underlying* detail when a star
        // card is pushed onto the stack. When the user pops back,
        // this view reappears — `.onAppear` re-pans the canvas to
        // the constellation centroid so the underlying map matches
        // the active card again. Fires once on initial open too,
        // harmlessly re-panning to where `focus(on:)` already put
        // the camera.
        .onAppear { state.panTo(.constellation(constellation)) }
        .navigationDestination(for: EStar.self) { s in
            // Pushed from the constellation roster — there IS a
            // sensible parent (this constellation) to pop back to,
            // so the star detail's chevron-back is meaningful here.
            EStarDetailView(star: s, showsBackChevron: true)
        }
    }

    // MARK: Roster

    /// Same 100-pt fixed-height row + tile padding as the star
    /// detail's stats grid so the two surfaces share a rhythm.
    private var rosterHeight: CGFloat { 100 }

    private var roster: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(stars.prefix(12)) { star in
                    NavigationLink(value: star) {
                        StarCard(star: star)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: rosterHeight)
    }
}

// `StarCard` lives in View/Cards/EFavouriteCards.swift and is
// shared with the SearchSheet's favourites scroll.

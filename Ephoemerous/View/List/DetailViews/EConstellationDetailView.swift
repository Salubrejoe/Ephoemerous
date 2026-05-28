import SwiftUI

struct EConstellationDetailView: View {
    @Environment(EAppState.self) var state
    let constellation: EConstellation

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
    /// the constellation's POI badge shows on the canvas.
    private var iconSymbolName: String {
        EArtist.shared.constellationEntitySymbol(
            EArtist.shared.constellationEntity(of: constellation)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:    constellation.fullName,
                subtitle: subtitleText,
                accent:   accent,
                icon:     { Image(systemName: iconSymbolName) },
                onShare:  {},
                onDismiss: { state.dismissDetail() }
            )
            RememberButton(obj: .constellation(constellation))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            List {
                Section {
                    if !stars.isEmpty {
                        ForEach(stars.prefix(12)) { star in
                            NavigationLink(value: star) {
                                EConstellationStarRow(star: star)
                            }
                            .padding(.leading, 33)
                            .overlay {
                                FavouriteButton(star: star)
                                    .scaleEffect(0.6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        if stars.count > 12 {
                            Text("...and \(stars.count - 12) more")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        // No side effects on the sky from this view itself — no
        // auto-tracking the brightest star, no border selection — it
        // just renders the constellation's roster. The opening flow
        // (which sets `detailDestination` and pans the canvas) lives
        // in `EAppState.focus(on:)`.
        .navigationDestination(for: EStar.self) { s in
            EStarDetailView(star: s).onAppear { state.recordViewed(s) }
        }
    }
}

// MARK: - Star row

private struct EConstellationStarRow: View {
    let star: EStar

    var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(star.displayName)
                    .font(.body)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f mag", star.magnitude))
                        .font(.caption)
                        .monospacedDigit()
                        .fontDesign(.serif)
                        .foregroundStyle(.secondary)
                }
            }
        
    }
}

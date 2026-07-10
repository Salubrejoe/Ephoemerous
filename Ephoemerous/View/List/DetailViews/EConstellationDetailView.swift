import SwiftUI
import LoreKit

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

    /// On-device "how it reached the sky" storyteller. Lives for this
    /// view's lifetime — the detail host keys identity on the object
    /// (`.id(obj.id)` in MainView), so a new constellation gets a fresh
    /// teller and a fresh telling.
    @State private var storyteller = MythStoryteller()

    /// Voice of the telling. Changing it re-generates via the story
    /// section's `.task(id:)`.
    @State private var tone: MythStoryteller.Tone = .cosy

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
        // Just what it depicts now (hero / animal / …) — the myth cycle
        // taxonomy is retired, so no "in the X Myth" suffix.
        EArtist.shared.constellationEntity(of: constellation).localizedName
    }

    /// Neutral constellation accent — one tint for every constellation now.
    private var accent: Color {
        EArtist.shared.constellationGradient.top
    }

    /// Entity symbol from the existing POI palette — same SF Symbol
    /// the constellation's POI badge used on the canvas when it
    /// still had a badge.
    private var iconSymbol: ESymbol {
        EArtist.shared.constellationEntitySymbol(
            EArtist.shared.constellationEntity(of: constellation)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:         constellation.localizedName,
                subtitle:      subtitleText,
                accent:        accent,
                icon:          { EmptyView() },
                leadingSymbol: .share,
                onLeading:     {},
                onDismiss:     { state.dismissDetail() }
            )
            if !collapsed {
                // Scrolls as one when the sheet is dragged up past the
                // resting third — action row + roster sit above the
                // fold, the origin story flows below it.
                ScrollView {
                    VStack(spacing: 0) {
                        
                        DetailActionRow(obj: .constellation(constellation))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        roster
                        storySection
                            .padding(.horizontal, 16)
                            .padding(.top,        20)
                            .padding(.bottom,     28)
                    }
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .navigationDestination(for: EStar.self) { s in
            // Pushed from the constellation roster — there IS a
            // sensible parent (this constellation) to pop back to,
            // so the star detail's chevron-back is meaningful here.
            EStarDetailView(star: s, showsBackChevron: true)
        }
    }

    // MARK: Roster

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
            .padding(.vertical, 12)
        }
    }

    // MARK: Origin story

    /// The emotional centrepiece: the on-device model retells how this
    /// figure was set among the stars, in the chosen voice. Grounded in
    /// the curated catasterism line + cultural category + one live star
    /// fact (see `MythStoryteller`). On the Simulator — or any device
    /// without Apple Intelligence — it falls back to the raw curated
    /// line so there's always something to read.
    private var storySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "book")
                    .font(.footnote)
                    .foregroundStyle(accent)
                Text("How it reached the sky")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
            }

            Picker("Tone", selection: $tone) {
                ForEach(MythStoryteller.Tone.allCases) { t in
                    Text(t.label).tag(t)
                }
            }
            .pickerStyle(.segmented)

            storyBody
        }
        // Fires on appear and whenever the tone segment changes; the
        // teller cancels any in-flight telling before starting the next.
        .task(id: tone) { storyteller.tell(constellation, tone: tone) }
    }

    @ViewBuilder
    private var storyBody: some View {
        switch storyteller.phase {
        case .idle, .generating:
            HStack(spacing: 10) {
                ProgressView()
                Text("Just a sec...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)

        case .ready, .fallback:
            if storyteller.text.isEmpty {
                // Modern constellation with no curated line, model
                // unavailable — nothing to show, so say so warmly.
                Text("Its story unfolds on your device.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text(storyteller.text)
                    .font(.callout)
                    .fontDesign(.serif)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }
}

// `StarCard` lives in View/Cards/EFavouriteCards.swift and is
// shared with the SearchSheet's favourites scroll.


#Preview {
    EConstellationDetailView(constellation: .And)
        .environment(EAppState())
}

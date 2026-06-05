import SwiftUI
import LoreKit

// MARK: - EMythDetailView
// Detail sheet for a mythological cycle (Perseus / Hercules / Argo /
// Zeus / Orion / Orpheus). Same rhythm as `EConstellationDetailView`:
// header → horizontal scroll of constellation cards (every
// constellation whose primary myth is this one) → horizontal scroll
// of story beat cards (the cycle split into bite-sized chapters that
// name the constellations as they enter the tale).
//
// Two stacked horizontal scrolls let the bottom-third sheet stay
// terse on first reveal — the user expands the sheet to read the
// story without losing the constellation roster's spatial anchor.
//
// No `RememberButton` here yet — myths aren't `ESkyObject`s and
// aren't favourite-able. Wiring (a `detailDestination` case for
// `.myth(POIConstellationMyth)`) is deliberately deferred; this
// view stands alone until then.

struct EMythDetailView: View {
    @Environment(EAppState.self) var state
    let myth: POIConstellationMyth

    // MARK: Derived

    /// Every constellation whose *primary* myth is this one — same
    /// `myths.first` rule `EArtist.constellationMyth(of:)` already
    /// uses, so the roster matches the colour family of the badges.
    /// Sorted alphabetically by full name for a stable read order.
    private var constellations: [EConstellation] {
        EConstellation.allCases
            .filter { $0 != .none }
            .filter { EArtist.shared.constellationMyth(of: $0) == myth }
            .sorted { $0.fullName < $1.fullName }
    }

    /// Capitalised raw value — "Perseus", "Hercules", … The enum has
    /// no display-name property so we capitalise the JSON key.
    private var titleText: String { myth.localizedTitle }

    /// One-line tagline per cycle. Tells the reader what the story
    /// is *about* in seven words or fewer — same role
    /// `EConstellationDetailView`'s subtitle plays for an entity.
    /// Strings live on `POIConstellationMyth.tagline` so the
    /// LearnMyth pill in `DetailActionRow` reads from the same
    /// source.
    private var subtitleText: String { myth.tagline }

    /// Top of the myth gradient — same hue the cycle's constellation
    /// badges wear on the canvas. Threads the colour family through
    /// the detail sheet so badges and detail read as one species.
    private var accent: Color {
        EArtist.shared.constellationMythGradient(myth).top
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 16) {
            // Empty-view in the icon slot: the cycle's accent colour
            // already lives in every constellation badge below and in
            // the chapter ordinals — repeating it as a header glyph
            // muddied the page. Title + subtitle carry it.
            DetailHeader(
                title:         titleText,
                subtitle:      subtitleText,
                accent:        accent,
                icon:          { EmptyView() },
                leadingSymbol: .shareCircleFill,
                onLeading:     {},
                onDismiss:     { state.dismissMyth() }
            )

            constellationsSection

            if !storyBeats.isEmpty {
                storySection
            }

            Spacer(minLength: 0)
        }
        // Pan the canvas to the centroid of the first constellation
        // in the cycle when the sheet opens — gives the canvas a
        // sensible anchor even though "the myth" itself has no
        // single sky position. Skipped for `.none` (no anchor).
        .onAppear {
            guard let first = constellations.first else { return }
            state.panTo(.constellation(first))
        }
    }

    // MARK: Constellations roster

    /// Matches `EConstellationDetailView.rosterHeight` so the two
    /// detail surfaces share a 100-pt horizontal-card rhythm.
    private var rosterHeight: CGFloat { 100 }

    private var constellationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(String(localized: "Constellations"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(constellations, id: \.self) { cons in
                        ConstellationCard(constellation: cons)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: rosterHeight)
        }
    }

    // MARK: Story roster

    /// Beat-card geometry. Wider + taller than a constellation card
    /// because each card carries an ordinal, a beat title, and a
    /// short body paragraph.
    private var storyCardWidth:  CGFloat { 260 }
    private var storyCardHeight: CGFloat { 160 }

    private var storySection: some View {
        // Inner spacing is 12 to match the constellations section,
        // but the *story* card has its ordinal flush at the
        // top-leading instead of centred content. With only 8 pt
        // between "STORY" and the ordinal "I", the two read as one
        // continuous string ("STORY I — The Hunter") instead of
        // a section heading + a chapter. The extra breath fixes it.
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(String(localized: "Story"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(storyBeats.enumerated()), id: \.offset) { _, beat in
                        beatCard(beat)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: storyCardHeight)
        }
    }

    private func beatCard(_ beat: Beat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(beat.ordinal)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .tracking(1.0)
            Text(beat.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(beat.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(5)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .frame(width:  storyCardWidth,
               height: storyCardHeight,
               alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical,   12)
        .background(Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Section header

    /// Small uppercase label above each horizontal scroll. The
    /// constellation detail's single roster doesn't need a label
    /// (the cards speak for themselves), but stacking two rosters
    /// here without naming them reads as one confusing pile.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 16)
    }

    // MARK: Story content

    /// One beat in the cycle. Ordinals are Roman so the cards read
    /// as chapters of a book rather than a numbered list.
    private struct Beat {
        let ordinal: String
        let title:   String
        let body:    String
    }

    /// The cycle split into bite-sized scenes. Each beat names the
    /// constellations that enter the tale at that point so the user
    /// can pivot between the story scroll and the constellation
    /// scroll and feel "these are the same characters".
    ///
    /// Body copy is held to ~30 words a beat — any longer and the
    /// card grows past its 5-line slot. Long-form lore belongs in a
    /// dedicated reading view, not on a horizontal card.
    private var storyBeats: [Beat] {
        switch myth {
        case .perseus:  return perseusBeats
        case .hercules: return herculesBeats
        case .argo:     return argoBeats
        case .zeus:     return zeusBeats
        case .orion:    return orionBeats
        case .orpheus:  return orpheusBeats
        case .none:     return []
        }
    }

    private var perseusBeats: [Beat] { [
        Beat(ordinal: "I",
             title:   String(localized: "The Boast"),
             body:    String(localized: "Queen Cassiopeia declares her daughter Andromeda more beautiful than the Nereids — and the sea-god Poseidon hears her.")),
        Beat(ordinal: "II",
             title:   String(localized: "The Sacrifice"),
             body:    String(localized: "To appease Poseidon's sea-monster Cetus, king Cepheus chains Andromeda to a coastal rock and walks away.")),
        Beat(ordinal: "III",
             title:   String(localized: "The Hero Arrives"),
             body:    String(localized: "Perseus, returning from beheading Medusa, sweeps in on the winged horse Pegasus and finds the princess in chains.")),
        Beat(ordinal: "IV",
             title:   String(localized: "The Petrifaction"),
             body:    String(localized: "Perseus lifts the Gorgon's head from his bag. Cetus turns to stone in the surf, and Andromeda is freed.")),
    ] }

    private var herculesBeats: [Beat] { [
        Beat(ordinal: "I",
             title:   String(localized: "The Twelve Labours"),
             body:    String(localized: "Driven mad by Hera, Heracles slays his own family. To atone he must complete twelve impossible labours for king Eurystheus.")),
        Beat(ordinal: "II",
             title:   String(localized: "The Nemean Lion"),
             body:    String(localized: "His first labour: strangle the invulnerable Lion of Nemea. Heracles wears its golden pelt for the rest of his life.")),
        Beat(ordinal: "III",
             title:   String(localized: "Hydra and Crab"),
             body:    String(localized: "He burns the necks of the many-headed Hydra. Hera sends a giant Crab to pinch his heel — Heracles crushes it underfoot.")),
        Beat(ordinal: "IV",
             title:   String(localized: "The Sleepless Dragon"),
             body:    String(localized: "To steal the golden apples of the Hesperides he must slip past Ladon — the dragon Draco, coiled around their tree.")),
    ] }

    private var argoBeats: [Beat] { [
        Beat(ordinal: "I",
             title:   String(localized: "The Golden Ram"),
             body:    String(localized: "The ram Chrysomallos — fleece of pure gold — carries the children Phrixus and Helle out of Boeotia and is sacrificed in Colchis.")),
        Beat(ordinal: "II",
             title:   String(localized: "The Argo Sails"),
             body:    String(localized: "Jason builds the ship Argo and gathers fifty heroes — Heracles, Orpheus, the Dioscuri — to recover the fleece.")),
        Beat(ordinal: "III",
             title:   String(localized: "The Crossing"),
             body:    String(localized: "They thread the Clashing Rocks, escape the Harpies, and reach Colchis, where king Aeëtes guards the prize.")),
        Beat(ordinal: "IV",
             title:   String(localized: "The Fleece Won"),
             body:    String(localized: "With sorceress Medea's help Jason charms the sleepless dragon, seizes the fleece, and the Argo flees for home.")),
    ] }

    private var zeusBeats: [Beat] { [
        Beat(ordinal: "I",
             title:   String(localized: "Ganymede's Cup"),
             body:    String(localized: "Zeus takes the shape of an eagle and carries the beautiful boy Ganymede to Olympus to be cupbearer to the gods.")),
        Beat(ordinal: "II",
             title:   String(localized: "Leda and the Swan"),
             body:    String(localized: "Disguised as a swan, Zeus visits Leda. From the union are born the twin heroes Castor and Pollux.")),
        Beat(ordinal: "III",
             title:   String(localized: "Europa and the Bull"),
             body:    String(localized: "As a snow-white bull Zeus carries the Phoenician princess Europa across the sea to Crete, where she bears him Minos.")),
        Beat(ordinal: "IV",
             title:   String(localized: "Callisto's Bear"),
             body:    String(localized: "Hera transforms Zeus's lover Callisto into a bear. Zeus lifts her into the sky as a great bear, safe forever.")),
    ] }

    private var orionBeats: [Beat] { [
        Beat(ordinal: "I",
             title:   String(localized: "The Hunter"),
             body:    String(localized: "Orion, son of Poseidon, walks the night with his two hounds — Canis Major and Canis Minor — chasing the hare Lepus through the sky.")),
        Beat(ordinal: "II",
             title:   String(localized: "The Boast"),
             body:    String(localized: "Orion vows to kill every animal on earth. Gaia, mother of beasts, recoils — and sends a punishment shaped like a scorpion.")),
        Beat(ordinal: "III",
             title:   String(localized: "The Sting"),
             body:    String(localized: "Scorpius emerges from the ground and stings the hunter dead. The gods set them at opposite ends of the sky so they never meet again.")),
    ] }

    private var orpheusBeats: [Beat] { [
        Beat(ordinal: "I",
             title:   String(localized: "The Lyre"),
             body:    String(localized: "Apollo gives Orpheus a lyre. He plays so beautifully that trees lean toward him and rivers slow to listen.")),
        Beat(ordinal: "II",
             title:   String(localized: "Eurydice Lost"),
             body:    String(localized: "His bride Eurydice is bitten by a viper and dies. Orpheus descends into Hades to bring her back.")),
        Beat(ordinal: "III",
             title:   String(localized: "The Backward Glance"),
             body:    String(localized: "Hades agrees on one condition: Orpheus must not look back until they reach the upper world. He looks — and she is gone.")),
        Beat(ordinal: "IV",
             title:   String(localized: "The Lyre in the Sky"),
             body:    String(localized: "After his death the Muses set his lyre among the stars as Lyra; the swan Cygnus sails the Milky Way close by.")),
    ] }
}

// MARK: - Preview

#Preview("Perseus") {
    EMythDetailView(myth: .perseus)
        .environment(EAppState())
}

#Preview("Hercules") {
    EMythDetailView(myth: .hercules)
        .environment(EAppState())
}

#Preview("Orion") {
    EMythDetailView(myth: .orion)
        .environment(EAppState())
}

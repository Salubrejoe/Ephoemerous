import SwiftUI
import LoreKit

// MARK: - SkyShareCard
// The postcard you send someone: the REAL sky over your spot, at the moment
// you looked, with one object held up in it.
//
// It is not a screenshot and not the widget tile. It renders through the
// same `SkySnapshot` the widget uses — the same stereographic projection,
// star catalogue and constellation figures — but composed for a photo roll
// instead of a Home Screen: 4:5 (what Messages and Instagram treat kindly),
// the object lifted above centre, and a footer that says WHAT, WHERE and
// WHEN so the card still means something a month later. The widget's "Now"
// freshness language would age badly in someone else's camera roll.
//
// Rendered to PNG by `SkyPostcard` (Transferable) — see that file for the
// share plumbing. Nothing here is interactive; it exists to be drawn once.
struct SkyShareCard: View {

    let object:    SkyObject
    let date:      Date
    let latDeg:    Double
    let lonDeg:    Double
    /// Resolved town, when the app knows one (`AppState.localityName`).
    /// Falls back to coordinates so the card is never anonymous.
    let placeName: String?

    /// Design size in points. Rendered at `SkyPostcard.renderScale` for the
    /// actual pixels (×3 → 1200 × 1500). ▼ TWEAK the card's proportions ▼
    static let size = CGSize(width: 400, height: 500)

    /// Where the object sits — above centre, clear of the footer block.
    private var focus: CGPoint {
        CGPoint(x: Self.size.width * 0.5, y: Self.size.height * 0.40)
    }

    @MainActor
    private var snapshot: SkySnapshot {
        SkySnapshot(entity:      SkyObjectEntity(object),
                    date:        date,
                    origin:      (latDeg: latDeg, lonDeg: lonDeg),
                    size:        Self.size,
                    isLandscape: false,
                    focus:       focus)
    }

    var body: some View {
        let snap = snapshot

        ZStack(alignment: .bottomLeading) {
            Artist.shared.canvasBackground

            // The sky: stars, constellation figures + names, the horizon.
            // A denser field than any widget — this is a big canvas and the
            // card wants to feel like a real night.
            Canvas { ctx, size in
                snap.draw(in: &ctx, size: size, magnitudeLimit: 5.4)
            }

            // The other wanderers, in the app's flat POI grammar.
            ForEach(snap.bodies(excluding: SkyObjectEntity(object).id,
                                in: Self.size), id: \.2) { category, point, name in
                flatLabel(category, name: name)
                    .position(point)
            }

            // The hero. Constellations have no badge — their figure is
            // already traced solid by `snap.draw`, which IS the promotion.
            if let category, snap.pinnedConstellation == nil {
                promotedBadge(category)
            }

            scrim
            footer
        }
        .overlay(alignment: .topTrailing) { wordmark }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)   // it is the night sky
    }

    /// The signature, top-trailing — a corner the sky rarely fills, and
    /// well clear of the footer (which wraps to two lines in languages
    /// with longer date phrasing). Faint, with a dark halo so it holds
    /// against a bright star field without shouting.
    private var wordmark: some View {
        Text("Ephemerous")
            .font(.system(size: 12, weight: .semibold, design: .serif))
            .foregroundStyle(.white.opacity(0.5))
            .shadow(color: Artist.shared.canvasBackground.opacity(0.9), radius: 3)
            .padding(.top, 20)
            .padding(.trailing, 22)
    }

    // MARK: Pieces

    /// Keeps the footer legible over a busy starfield without dimming the
    /// whole card — the sky stays sharp above the fold.
    private var scrim: some View {
        LinearGradient(colors: [.clear,
                                Artist.shared.canvasBackground.opacity(0.55),
                                Artist.shared.canvasBackground.opacity(0.92)],
                       startPoint: .center, endPoint: .bottom)
            .allowsHitTesting(false)
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(object.displayName)
                    .font(.system(size: 34, weight: .heavy, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // Where to actually look — the line that makes the card
                // useful rather than decorative. Constellations get nil.
                if let altAz = snapshot.altitudeAzimuthLabel {
                    Text(altAz)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Text(whereAndWhen)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    /// "Florence · 30 Jul 2026, 21:40" — or coordinates when no town has
    /// been resolved, so the card always states its own provenance.
    ///
    /// Abbreviated deliberately: the wide-month form renders as "30 luglio
    /// 2026 alle ore 10:10" in Italian, which wrapped the footer onto two
    /// lines. This stays on one line in every locale I can throw at it.
    private var whereAndWhen: String {
        let when = date.formatted(date: .abbreviated, time: .shortened)
        if let placeName, !placeName.isEmpty { return "\(placeName) · \(when)" }
        let lat = String(format: "%.1f°%@", abs(latDeg), latDeg >= 0 ? "N" : "S")
        let lon = String(format: "%.1f°%@", abs(lonDeg), lonDeg >= 0 ? "E" : "W")
        return "\(lat) \(lon) · \(when)"
    }

    @MainActor
    private var category: POICategory? {
        switch object {
        case .star(let s):   .followedStar(s)
        case .sun:           .sun
        case .moon:          .moon
        case .planet(let p): .planet(p)
        case .constellation: .constellation
        }
    }

    /// Stars — the Sun included — wear the pointy 5-corner squircle;
    /// planetoids stay rounded. Same rule as the canvas and the widgets.
    private func labelStyle(for category: POICategory) -> POILabelView.LabelStyle {
        switch category {
        case .sun, .followedStar, .namedStar: .star
        default:                              .planetoids
        }
    }

    /// The hero badge, oversized, sitting exactly on the object's own
    /// projection (see `focus`). No separate precise-location dot: the
    /// widget lifts its badge ABOVE the dot, but here badge and dot share
    /// a centre, so the dot would just be a blemish inside the pentagon.
    @MainActor
    private func promotedBadge(_ category: POICategory) -> some View {
        let style: CGFloat = 3.0            // ▼ TWEAK the hero badge size ▼
        return POILabelView(category:   category,
                            text:       "",
                            labelStyle: labelStyle(for: category),
                            nameReveal: 0,
                            borderScaleCompensation: 1 / style)
            .scaleEffect(style)
            .position(focus)
    }

    /// An unpromoted body — badge + trailing name, the app's flat POI
    /// treatment at this zoom.
    @MainActor
    private func flatLabel(_ category: POICategory, name: String) -> some View {
        let style = Artist.shared.poiStyle(for: category)
        return POILabelView(category:    category,
                            text:        name,
                            labelStyle:  labelStyle(for: category),
                            badgeReveal: POILabelView.tierReveal(scale: 110,
                                                                 threshold: style.badgeIn),
                            nameReveal:  POILabelView.tierReveal(scale: 110,
                                                                 threshold: style.textIn))
    }
}

#if DEBUG
// The real 4:5 postcard, at its true design size.
#Preview("Postcard") {
    SkyShareCard(object: .star(PreviewSky.someStar),
                 date: PreviewSky.date,
                 latDeg: 43.77, lonDeg: 11.25,
                 placeName: "Florence")
}
#endif

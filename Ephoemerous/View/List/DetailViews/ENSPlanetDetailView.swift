import SwiftUI
import LoreKit

// MARK: - ENSPlanetDetailView
// Three-tile compact planet detail. Same shape as the star detail —
// header + Remember button + a single HStack of Distance / Period /
// Magnitude tiles. Fits the bottom-third sheet detent without
// scrolling.

struct ENSPlanetDetailView: View {
    @Environment(EAppState.self) var state
    @Environment(\.detailCollapsed) private var collapsed
    let planet: EPlanet

    private var accent: Color { planet.color }

    private var facts: PlanetFacts? { PlanetFacts.lookup[planet.name] }

    /// Civil-twilight anchors for the current observation date +
    /// observer latitude. Planets are night-sky objects (mostly
    /// visible when the sun is below the horizon), so the moon
    /// gradient — cool indigo / lavender / silver — reads as their
    /// natural visibility window. The knob carries the planet's
    /// astronomical Unicode glyph so each planet still feels
    /// distinct.
    private var anchors: SunDayAnchors {
        ESunPosition.dayAnchors(
            for: state.observationDate,
            latitude: state.origin.latitude.degrees
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:         planet.name,
                subtitle:      planet.mythology,
                accent:        accent,
                icon:          { POIBadgeView(category: .planet(planet)) },
                leadingSymbol: .shareCircleFill,
                onLeading:     {},
                onDismiss:     { state.dismissDetail() }
            )
            // No RememberButton — planets, sun, and moon aren't
            // favouritable. The favourites system is for the things
            // that *change in the sky*: stars (relationships) and
            // constellations (stories you return to). Solar-system
            // bodies are always there, always badged on the canvas.
            if !collapsed {
                DayCapsule(
                    tint:      accent,
                    knobGlyph: .unicode(planet.astronomicalGlyph),
                    knobDate:  Bindable(state).observationDate
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                statsRow
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Stats row

    /// Fixed row height — every tile fills this exactly, guaranteeing
    /// the three backgrounds line up regardless of which SF Symbol
    /// happens to render slightly shorter than the others. Same value
    /// the star detail uses so the two surfaces share a rhythm.
    private var statsRowHeight: CGFloat { 100 }

    /// Distance (from the Sun, AU) carries the accent so the planet's
    /// colour shows up exactly once in the detail body. The other
    /// two tiles stay neutral.
    private var statsRow: some View {
        HStack(spacing: 8) {
            tile(icon:     "ruler",
                 iconTint: accent,
                 value:    facts?.distance ?? "—",
                 label:    Strings.BodyDetail.distance)
            tile(icon:     "clock",
                 iconTint: .secondary,
                 value:    facts?.period ?? "—",
                 label:    Strings.BodyDetail.period)
            tile(icon:     "sparkles",
                 iconTint: .secondary,
                 value:    magnitudeText,
                 label:    Strings.BodyDetail.magnitude)
        }
        .frame(height: statsRowHeight)
    }

    private func tile(icon: String, iconTint: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            // Fixed-height slots so the value + label rows below line
            // up across all three tiles regardless of the SF Symbol's
            // intrinsic height (ruler short, clock medium, sparkles
            // tall-ish).
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

    private var magnitudeText: String {
        String(format: "%.1f", planet.baseMagnitude)
    }
}

// MARK: - Planet facts
// Static reference data — distance from the Sun (semi-major axis in
// AU), diameter, and orbital period. Lifted to file scope so the
// detail body can look up by planet name without going through a
// nested view.
private struct PlanetFacts {
    let diameter: String
    let distance: String
    let period:   String

    static let lookup: [String: PlanetFacts] = [
        Strings.Planets.mercury: PlanetFacts(diameter: "4,879 km",   distance: "0.39 AU", period: "88 days"),
        Strings.Planets.venus:   PlanetFacts(diameter: "12,104 km",  distance: "0.72 AU", period: "225 days"),
        Strings.Planets.mars:    PlanetFacts(diameter: "6,779 km",   distance: "1.52 AU", period: "687 days"),
        Strings.Planets.jupiter: PlanetFacts(diameter: "139,820 km", distance: "5.20 AU", period: "11.9 yr"),
        Strings.Planets.saturn:  PlanetFacts(diameter: "116,460 km", distance: "9.58 AU", period: "29.5 yr"),
        Strings.Planets.uranus:  PlanetFacts(diameter: "50,724 km",  distance: "19.2 AU", period: "84.0 yr"),
        Strings.Planets.neptune: PlanetFacts(diameter: "49,244 km",  distance: "30.1 AU", period: "164.8 yr"),
    ]
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ENSPlanetDetailView(planet: .mars)
    }
    .environment(EAppState())
}

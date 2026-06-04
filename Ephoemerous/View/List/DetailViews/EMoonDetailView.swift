import SwiftUI
import LoreKit

// MARK: - EMoonDetailView
// Moon detail. Mirror of the sun layout — DetailHeader + horizontal
// scroll of 100-pt fact cards, no RememberButton. Tonight's events
// (moonrise / phase / moonset / illumination) tint lunar blue;
// physical + coordinate cards stay neutral.

struct EMoonDetailView: View {
    @Environment(EAppState.self) var state
    @Environment(\.detailCollapsed) private var collapsed

    private var moonData: (ra: Double, dec: Double, fraction: Double) {
        let (_, ra, dec) = EMoonPosition.vector(
            for: state.observationDate,
            siderealOffset: state.precessedSiderealOffset
        )
        let fraction = EMoonPosition.illuminatedFraction(for: state.observationDate)
        return (ra, dec, fraction)
    }

    /// Cool moonlight tint — same colour the old detail view used.
    private let accent = Color(red: 0.75, green: 0.82, blue: 1.0)

    /// Civil-twilight anchors for the current observation date +
    /// observer latitude. Moon visibility is the inverse of sun
    /// visibility, so the moon gradient uses the SAME anchors — peak
    /// moonlight at midnight, washout at noon, transitions at the
    /// twilight points.
    private var anchors: SunDayAnchors {
        ESunPosition.dayAnchors(
            for: state.observationDate,
            latitude: state.origin.latitude.degrees
        )
    }

    /// Phase name from `moonData.fraction`, falling back through the
    /// same threshold table the old view used.
    private var phaseName: String {
        switch moonData.fraction {
        case ..<AstroConstants.phaseNewMoon:        return Strings.MoonPhase.newMoon
        case ..<AstroConstants.phaseWaxingCrescent: return Strings.MoonPhase.waxingCrescent
        case ..<AstroConstants.phaseFirstQuarter:   return Strings.MoonPhase.firstQuarter
        case ..<AstroConstants.phaseWaxingGibbous:  return Strings.MoonPhase.waxingGibbous
        case ..<AstroConstants.phaseFullMoon:       return Strings.MoonPhase.fullMoon
        case ..<AstroConstants.phaseWaningGibbous:  return Strings.MoonPhase.waningGibbous
        case ..<AstroConstants.phaseLastQuarter:    return Strings.MoonPhase.lastQuarter
        case ..<AstroConstants.phaseWaningCrescent: return Strings.MoonPhase.waningCrescent
        default:                                    return Strings.MoonPhase.unknown
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                title:         "Moon",
                subtitle:      String(format: "%.0f%% illuminated", moonData.fraction * 100),
                accent:        accent,
                icon:          { POIBadgeView(category: .moon) },
                leadingSymbol: .shareCircleFill,
                onLeading:     {},
                onDismiss:     { state.dismissDetail() }
            )
            // No event dots — `WeatherKit` only returns a ~10-day
            // daily forecast, so out-of-range observation dates would
            // either return nothing or hold the last fetched day's
            // events stale on the capsule. The gradient + knob alone
            // are honest. Re-add `events: dayEvents` here when we
            // compute date-accurate moonrise / moonset ourselves.
            if !collapsed {
                DayCapsule(
                    gradient:  .dayCapsuleMoon(anchors: anchors),
                    knobGlyph: .symbol(.moonFill),
                    knobDate:  Bindable(state).observationDate
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                roster
                    .padding(.top, 16)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Roster

    private var rosterHeight: CGFloat { 100 }

    private var roster: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                eventCards
                physicalCards
                coordCards
            }
            .padding(.horizontal, 16)
        }
        .frame(height: rosterHeight)
    }

    // MARK: Card groups

    /// Moonrise + moonset have moved onto the DayCapsule. Phase +
    /// illumination remain as cards because they're not points in
    /// time — phase is a state of being and illumination is a
    /// percentage, neither maps onto a 24h timeline.
    @ViewBuilder
    private var eventCards: some View {
        card(icon: phaseSymbol(for: phaseName), accentTinted: true,
             value: phaseName, label: "Phase")
        card(icon: "circle.lefthalf.filled",    accentTinted: true,
             value: String(format: "%.0f%%", moonData.fraction * 100),
             label: "Illumination")
    }

    private var physicalCards: some View {
        Group {
            card(icon: "ruler",         accentTinted: false, value: "~384k km", label: "Distance")
            card(icon: "circle.dashed", accentTinted: false, value: "3,474 km", label: "Diameter")
            card(icon: "clock",         accentTinted: false, value: "27.3 d",   label: "Period")
        }
    }

    private var coordCards: some View {
        Group {
            card(icon: "arrow.left.arrow.right", accentTinted: false,
                 value: raString,  label: "RA")
            card(icon: "arrow.up.arrow.down", accentTinted: false,
                 value: decString, label: "Dec")
        }
    }

    // MARK: Card

    /// Same fixed-slot card shape as the sun detail / constellation
    /// roster — 110pt wide, 100pt tall row, icon 24 / value 22 /
    /// label 14 slot heights. Kept private here rather than shared
    /// because each detail view has slightly different layout
    /// concerns and a generic Card<View> ends up trickier than two
    /// inline copies.
    private func card(icon: String, accentTinted: Bool, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accentTinted ? accent : .secondary)
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
                .lineLimit(1)
                .frame(height: 14)
        }
        .frame(width: 110)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 14)
        .background(Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Helpers

    /// SF Symbol for the eight Moon phases — the canonical
    /// `moonphase.*` family. Falls back to plain `moon` if a phase
    /// string we don't recognise comes through.
    private func phaseSymbol(for name: String) -> String {
        switch name {
        case Strings.MoonPhase.newMoon:        return "moonphase.new.moon"
        case Strings.MoonPhase.waxingCrescent: return "moonphase.waxing.crescent"
        case Strings.MoonPhase.firstQuarter:   return "moonphase.first.quarter"
        case Strings.MoonPhase.waxingGibbous:  return "moonphase.waxing.gibbous"
        case Strings.MoonPhase.fullMoon:       return "moonphase.full.moon"
        case Strings.MoonPhase.waningGibbous:  return "moonphase.waning.gibbous"
        case Strings.MoonPhase.lastQuarter:    return "moonphase.last.quarter"
        case Strings.MoonPhase.waningCrescent: return "moonphase.waning.crescent"
        default:                               return "moon"
        }
    }

    private var raString: String {
        let hours = moonData.ra / 15
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return String(format: "%dh%02dm", h, m)
    }

    private var decString: String {
        "\(Int(moonData.dec.rounded()))°"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EMoonDetailView()
    }
    .environment(EAppState())
}

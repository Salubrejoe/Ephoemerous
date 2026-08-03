import SwiftUI
import LoreKit

// MARK: - MoonDetailView
// Moon detail. Mirror of the sun layout — DetailHeader + horizontal
// scroll of 100-pt fact cards, no RememberButton. Tonight's events
// (moonrise / phase / moonset / illumination) tint lunar blue;
// physical + coordinate cards stay neutral.

struct MoonDetailView: View {
    @Environment(AppState.self) var state
    @Environment(\.detailCollapsed) private var collapsed

    private var moonData: (ra: Double, dec: Double, fraction: Double) {
        let (_, ra, dec) = MoonPosition.vector(
            for: state.observationDate,
            siderealOffset: state.precessedSiderealOffset
        )
        let fraction = MoonPosition.illuminatedFraction(for: state.observationDate)
        return (ra, dec, fraction)
    }

    /// Civil-twilight anchors for the current observation date +
    /// observer latitude. Moon visibility is the inverse of sun
    /// visibility, so the moon gradient uses the SAME anchors — peak
    /// moonlight at midnight, washout at noon, transitions at the
    /// twilight points.
    private var anchors: SunDayAnchors {
        SunPosition.dayAnchors(
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
                title:         Strings.Bodies.moon,
                subtitle:      phaseName,
                accent:        .gray,
                icon:          {
                    Image(systemName: phaseSymbol(for: phaseName))
                },
                leadingSymbol: .share,
                onLeading:     {},
                postcard:      state.postcard(for: .moon),
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
                    tint:      .gray,
                    knobGlyph: .symbol(.moonFill),
                    knobDate:  Bindable(state).observationDate
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                DetailStatList(stats: [
                    .init(label: String(localized: "Phase"),           value: phaseName),
                    .init(label: String(localized: "Right ascension"), value: raString),
                    .init(label: String(localized: "Declination"),     value: decString),
                    .init(label: String(localized: "Distance"),        value: "~384,400 km"),
                    .init(label: String(localized: "Diameter"),        value: "3,474 km"),
                    .init(label: String(localized: "Orbital period"),  value: "27.3 days"),
                ])
                .padding(.top, 16)
                
            }
            Spacer(minLength: 0)
        }
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
        MoonDetailView()
    }
    .environment(AppState())
}

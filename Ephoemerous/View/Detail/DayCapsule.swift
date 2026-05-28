import SwiftUI
import LoreKit

// MARK: - DayCapsule
// 24-hour "day-glance" capsule that sits in the same layout slot
// (and shares the exact shape + height) as `RememberButton`.
// Visually it's a wide rounded pill filled with a continuous
// midnight → noon → midnight gradient, with optional event dots
// positioned along its width by time-of-day fraction (0h on the
// left edge, 24h on the right).
//
// Two initialisers:
//   • Plain — just the gradient + dots.
//   • Interactive — adds a glass knob bound to an external
//     `Date`. Dragging the capsule scrubs the bound date through
//     the current calendar day (preserves Y-M-D, only changes
//     hours / minutes / seconds). Tap anywhere on the capsule
//     jumps the knob there; drag scrubs continuously.
struct DayCapsule: View {

    /// One event marker on the capsule — a time, a description for
    /// accessibility / future tooltips, and the dot's fill.
    struct Event: Identifiable {
        let id    = UUID()
        let time:  Date
        let label: String
        let color: Color
    }

    let events:     [Event]
    let gradient:   LinearGradient
    let knobSymbol: String?

    /// Bound externally — `nil`-equivalent when no knob is wanted
    /// (init uses `.constant(.now)` so the binding always exists).
    @Binding private var knobDate: Date

    // MARK: Init

    /// Read-only capsule (no draggable knob).
    init(events: [Event],
         gradient: LinearGradient = .dayCapsuleSun()) {
        self.events     = events
        self.gradient   = gradient
        self.knobSymbol = nil
        self._knobDate  = .constant(.now)
    }

    /// Interactive capsule — a glass knob (SF Symbol `knobSymbol`)
    /// rides on top of the gradient, bound to `knobDate`. Dragging
    /// the capsule scrubs the date through the current calendar
    /// day. `events` defaults to empty: today only WeatherKit-style
    /// daily forecasts (~10 days) can populate accurate sunrise /
    /// sunset / moonrise / moonset times, so callers pass dots
    /// only when they're certain the data is date-accurate.
    init(events:     [Event] = [],
         gradient:   LinearGradient,
         knobSymbol: String,
         knobDate:   Binding<Date>) {
        self.events     = events
        self.gradient   = gradient
        self.knobSymbol = knobSymbol
        self._knobDate  = knobDate
    }

    // MARK: Layout knobs

    /// Locked to the same height as RememberButton's intrinsic
    /// height (semibold body text + 14pt vertical padding) so the
    /// two components are interchangeable in the layout slot under
    /// the header.
    private var capsuleHeight: CGFloat { 50 }

    /// Glass knob is Apple-HIG-compliant 44pt — comfortably fits
    /// in the 50pt capsule with a small breathing margin.
    private var knobDiameter: CGFloat { 44 }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Capsule(style: .continuous)
                    .fill(gradient)

                ForEach(events) { event in
                    Circle()
                        .fill(event.color)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 0)
                        .position(
                            x: x(for: event.time, width: geo.size.width),
                            y: geo.size.height / 2
                        )
                        .accessibilityLabel("\(event.label) at \(event.time.timeString)")
                }

                if let symbol = knobSymbol {
                    Image(systemName: symbol)
                        .font(.body.weight(.semibold))
                        .frame(width: knobDiameter, height: knobDiameter)
                        .glassEffect(.clear.interactive(), in: .circle)
                        .position(
                            x: knobX(width: geo.size.width),
                            y: geo.size.height / 2
                        )
                        .accessibilityLabel("Time: \(knobDate.timeString)")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .contentShape(Capsule(style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard knobSymbol != nil else { return }
                        updateKnob(toX: value.location.x, width: geo.size.width)
                    }
            )
        }
        .frame(height: capsuleHeight)
    }

    // MARK: Knob math

    /// Knob centre X, clamped so the full knob stays within the
    /// capsule's width.
    private func knobX(width: CGFloat) -> CGFloat {
        let r = knobDiameter / 2
        let usable = max(width - 2 * r, 0)
        guard usable > 0 else { return width / 2 }
        let fraction = secondsOfDay(knobDate) / 86_400.0
        return r + CGFloat(fraction) * usable
    }

    /// Scrub the bound date to whatever wall-clock time the
    /// finger's x-coordinate maps to inside the knob's usable
    /// range. Calendar Y-M-D stays put — only the hours / minutes
    /// / seconds change.
    private func updateKnob(toX rawX: CGFloat, width: CGFloat) {
        let r = knobDiameter / 2
        let usable = max(width - 2 * r, 0)
        guard usable > 0 else { return }
        let clamped = min(max(rawX, r), width - r)
        let fraction = Double((clamped - r) / usable)
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: knobDate)
        let seconds = fraction * 86_400.0
        knobDate = startOfDay.addingTimeInterval(seconds)
    }

    // MARK: Event math

    /// Map a `Date` to an x-coordinate along the capsule. Uses the
    /// current calendar's wall-clock hour + minute, so the position
    /// reads as the local time-of-day regardless of timezone.
    private func x(for time: Date, width: CGFloat) -> CGFloat {
        let fraction = secondsOfDay(time) / 86_400.0
        return CGFloat(fraction) * width
    }

    /// Seconds-since-local-midnight for a date.
    private func secondsOfDay(_ time: Date) -> Double {
        let cal   = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: time)
        return Double((comps.hour ?? 0) * 3600
                    + (comps.minute ?? 0) * 60
                    + (comps.second ?? 0))
    }
}

// MARK: - Gradient palettes
// One source of truth for the two timeline palettes used today.
// Both are pastel by design — the capsule sits next to a saturated
// RememberButton in some layouts, and is the only colour body in
// others, so values stay low-chroma so they don't shout.
//
// The factories take a `SunDayAnchors` so the gradient stops can
// breathe with the observation: long bright zone in summer, narrow
// in winter, polar day/night handled via the `.default` fallback.
extension LinearGradient {

    /// Sun's 24h: dusty indigo at midnight → pale peach at civil
    /// dawn → cream at solar noon → dusty apricot at civil dusk →
    /// dusty indigo back at midnight. The three middle stops slide
    /// to wherever the observer's date + latitude puts the actual
    /// twilight transitions.
    static func dayCapsuleSun(anchors: SunDayAnchors = .default) -> LinearGradient {
        let dawn = anchors.civilDawnFraction ?? 0.25
        let noon = anchors.solarNoonFraction
        let dusk = anchors.civilDuskFraction ?? 0.75
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.22, green: 0.22, blue: 0.36), location: 0.00),
                .init(color: Color(red: 0.94, green: 0.80, blue: 0.74), location: dawn),
                .init(color: Color(red: 0.99, green: 0.94, blue: 0.78), location: noon),
                .init(color: Color(red: 0.94, green: 0.74, blue: 0.58), location: dusk),
                .init(color: Color(red: 0.22, green: 0.22, blue: 0.36), location: 1.00),
            ]),
            startPoint: .leading,
            endPoint:   .trailing
        )
    }

    /// Moon's 24h: deep indigo at midnight (peak moon visibility) →
    /// pale lavender at twilight → pale silver-grey at solar noon
    /// (moon washed out by the sun) → pale lavender → deep indigo.
    /// Same anchor structure as the sun gradient — moonlight rises
    /// as sunlight falls, so the two timelines breathe together.
    static func dayCapsuleMoon(anchors: SunDayAnchors = .default) -> LinearGradient {
        let dawn = anchors.civilDawnFraction ?? 0.25
        let noon = anchors.solarNoonFraction
        let dusk = anchors.civilDuskFraction ?? 0.75
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.20, green: 0.22, blue: 0.40), location: 0.00),
                .init(color: Color(red: 0.62, green: 0.66, blue: 0.80), location: dawn),
                .init(color: Color(red: 0.86, green: 0.88, blue: 0.93), location: noon),
                .init(color: Color(red: 0.62, green: 0.66, blue: 0.80), location: dusk),
                .init(color: Color(red: 0.20, green: 0.22, blue: 0.40), location: 1.00),
            ]),
            startPoint: .leading,
            endPoint:   .trailing
        )
    }
}

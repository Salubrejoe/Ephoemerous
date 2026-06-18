import SwiftUI
import UIKit
import LoreKit

// MARK: - DayCapsule
// 24-hour "day-glance" scrubber that sits in the same layout slot
// (and shares the height) as `RememberButton`. Instead of a continuous
// day/night gradient, it now shows a comb of 24 identical little vertical
// capsules — one per hour of the day — all in the object's body colour.
// They read as a tick scale, so dragging the knob gives an at-a-glance
// sense of *which hour* is being set (knob over the Nth bar ≈ N:00).
//
// Optional event dots sit along the scale by time-of-day fraction
// (0h at the left, 24h at the right).
//
// Two initialisers:
//   • Plain — just the hour bars + dots.
//   • Interactive — adds a glass knob bound to an external `Date`.
//     Dragging scrubs the bound date through the current calendar day
//     (preserves Y-M-D, only changes h/m/s). Tap jumps the knob there;
//     drag scrubs continuously, with a rigid "now" detent tick.
struct DayCapsule: View {

    /// One event marker on the capsule — a time, a description for
    /// accessibility / future tooltips, and the dot's fill.
    struct Event: Identifiable {
        let id    = UUID()
        let time:  Date
        let label: String
        let color: Color
    }

    let events:    [Event]
    /// The object's body colour — every hour bar is drawn in it.
    let tint:      Color
    let knobGlyph: POIGlyph?

    /// Bound externally — `nil`-equivalent when no knob is wanted
    /// (init uses `.constant(.now)` so the binding always exists).
    @Binding private var knobDate: Date

    /// Previous drag sample's seconds-of-day, for crossing detection.
    @State private var lastScrubbedSeconds: Double? = nil

    /// Crisp, subtle detent tap when the scrub crosses "now".
    private let nowHaptic = UIImpactFeedbackGenerator(style: .rigid)

    // MARK: Init

    /// Read-only capsule (no draggable knob).
    init(events: [Event], tint: Color) {
        self.events    = events
        self.tint      = tint
        self.knobGlyph = nil
        self._knobDate = .constant(.now)
    }

    /// Interactive capsule — a glass knob (SF Symbol or Unicode
    /// astronomical glyph, via `POIGlyph`) rides over the hour bars,
    /// bound to `knobDate`. `events` defaults to empty.
    init(events:    [Event] = [],
         tint:      Color,
         knobGlyph: POIGlyph,
         knobDate:  Binding<Date>) {
        self.events    = events
        self.tint      = tint
        self.knobGlyph = knobGlyph
        self._knobDate = knobDate
    }

    // MARK: Layout knobs

    /// A touch taller than RememberButton (50) to fit the hour numerals
    /// under the comb; still close enough to share the layout slot.
    private var capsuleHeight: CGFloat { 56 }
    /// Apple-HIG 44pt glass knob.
    private var knobDiameter:  CGFloat { 44 }

    /// One bar per hour.
    private var hourCount: Int     { 24 }
    private var barWidth:  CGFloat { 3 }
    private var barHeight: CGFloat { 22 }

    /// A numeral under every Nth hour bar — a ruler scale so the knob's
    /// position reads as a clock time at a glance.
    private var hourLabelStep: Int     { 2 }
    /// Gap from the bottom of a bar to the centre of its numeral.
    private var labelGap:      CGFloat { 8 }

    /// Vertical centre of the comb + knob, pinned so the 44pt knob clears
    /// the top edge (centre ≥ its radius) and leaves a band underneath for
    /// the hour numerals.
    private var trackY:  CGFloat { knobDiameter / 2 + 2 }
    /// Centre Y of the numeral band, just under the comb.
    private var labelY:  CGFloat { trackY + barHeight / 2 + labelGap }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Hour comb: 24 identical bars in the body colour, placed
                // on the SAME scale the knob uses, so bar h sits exactly
                // where the knob lands at h:00.
                ForEach(0..<hourCount, id: \.self) { h in
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: barWidth, height: barHeight)
                        .position(
                            x: x(forFraction: Double(h) / Double(hourCount),
                                 width: geo.size.width),
                            y: trackY
                        )
                }

                // Hour numerals every `hourLabelStep` hours, aligned under
                // their bar — the ruler scale that makes the slider read as
                // a clock (00, 02, … 22), capped one short of 24.
                ForEach(Array(stride(from: 0, to: hourCount, by: hourLabelStep)), id: \.self) { h in
                    Text("\(h)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .position(
                            x: x(forFraction: Double(h) / Double(hourCount),
                                 width: geo.size.width),
                            y: labelY
                        )
                }

                ForEach(events) { event in
                    Circle()
                        .fill(event.color)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 0)
                        .position(
                            x: x(forFraction: secondsOfDay(event.time) / 86_400.0,
                                 width: geo.size.width),
                            y: trackY
                        )
                        .accessibilityLabel("\(event.label) at \(event.time.timeString)")
                }

                if let glyph = knobGlyph {
                    knobView(for: glyph)
                        .frame(width: knobDiameter, height: knobDiameter)
                        .glassEffect(.clear.interactive(), in: .circle)
                        .position(
                            x: knobX(width: geo.size.width),
                            y: trackY
                        )
                        .accessibilityLabel("Time: \(knobDate.timeString)")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .contentShape(Capsule(style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard knobGlyph != nil else { return }
                        updateKnob(toX: value.location.x, width: geo.size.width)
                    }
                    .onEnded { _ in
                        lastScrubbedSeconds = nil
                        nowHaptic.prepare()
                    }
            )
        }
        .frame(height: capsuleHeight)
    }

    /// Render either an SF Symbol or a Unicode astronomical glyph at the
    /// knob's size — mirrors the canvas `drawPOILabel` switch.
    @ViewBuilder
    private func knobView(for glyph: POIGlyph) -> some View {
        switch glyph {
        case .sfSymbol(let name):
            Image(systemName: name)
                .font(.body.weight(.semibold))
//                .foregroundStyle(.primary)
        case .unicode(let str):
            Text(str)
                .font(.title3.weight(.semibold))
//                .foregroundStyle(.primary)
        }
    }

    // MARK: Scale math

    /// Map a 0…1 time-of-day fraction to an x inside the knob's usable
    /// travel (inset by the knob radius so the knob never clips the
    /// edges). Shared by the hour bars, the event dots, and the knob, so
    /// everything sits on one consistent scale.
    private func x(forFraction f: Double, width: CGFloat) -> CGFloat {
        let r = knobDiameter / 2
        let usable = max(width - 2 * r, 0)
        guard usable > 0 else { return width / 2 }
        return r + CGFloat(f) * usable
    }

    /// Knob centre X for the bound date.
    private func knobX(width: CGFloat) -> CGFloat {
        x(forFraction: secondsOfDay(knobDate) / 86_400.0, width: width)
    }

    /// Scrub the bound date to whatever wall-clock time the finger's
    /// x maps to. Calendar Y-M-D stays put — only h/m/s change. Seconds
    /// capped one under a full day so the far edge lands at 23:59:59
    /// rather than rolling over to 00:00 of the next day.
    private func updateKnob(toX rawX: CGFloat, width: CGFloat) {
        let r = knobDiameter / 2
        let usable = max(width - 2 * r, 0)
        guard usable > 0 else { return }
        let clamped = min(max(rawX, r), width - r)
        let fraction = Double((clamped - r) / usable)
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: knobDate)
        let seconds = min(fraction * 86_400.0, 86_399.0)
        knobDate = startOfDay.addingTimeInterval(seconds)

        tickIfCrossingNow(scrubbedSeconds: seconds, startOfDay: startOfDay)
    }

    /// Fire the detent haptic when the scrubbed time CROSSES real-now —
    /// a physical "notch" at the present moment, today only. Crossing
    /// (sign change of offset-from-now), so a fast flick still ticks.
    private func tickIfCrossingNow(scrubbedSeconds: Double, startOfDay: Date) {
        defer { lastScrubbedSeconds = scrubbedSeconds }

        let cal = Calendar.current
        guard cal.isDateInToday(startOfDay) else { return }

        let offset = scrubbedSeconds - secondsOfDay(.now)
        guard let previous = lastScrubbedSeconds else { return }
        let prevOffset = previous - secondsOfDay(.now)

        if offset == 0 || (prevOffset < 0) != (offset < 0) {
            nowHaptic.impactOccurred()
        }
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

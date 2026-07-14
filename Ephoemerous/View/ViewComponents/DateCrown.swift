import SwiftUI

// MARK: - DateCrown
// The time-travel instrument: a glass watch-crown / iPod-wheel hybrid.
// Drag around the disc and the observation date scrubs — the SKY above the
// sheet is the live preview (the same "domain is the control" recipe as the
// location picker's map). Flick it and it coasts; every detent ticks.
//
// A real watch crown has GEAR POSITIONS — pulled out one stop it sets the
// date, two stops the time. Ours shifts gears with the chips in the centre:
//
//   • Hours  — one lap = one day (one turn of the dial = one turn of the
//              sky, which is physically true). Scrubs by the minute,
//              ticks by the hour.
//   • Days   — one lap = 30 days; click per day, time-of-day held, so you
//              compare "same hour, night after night" (moon phases roll).
//   • Months — one lap = 12 months: the dial becomes the year-circle
//              (the zodiac wheel). Click per month.
//   • Years  — one lap = 12 years (≈ one Jupiter orbit). Click per year.
//
// Whole-unit stepping is deliberate — it keeps the wheel-picker's
// comparability (click, click, watch the sky change) that the stock
// UIDatePicker did well, while burying the form itself as the precise
// fallback behind the readout.
struct DateCrown: View {

    @Environment(EAppState.self) private var state

    // MARK: Gears

    enum Gear: String, CaseIterable, Identifiable {
        case hours, days, months, years
        var id: String { rawValue }

        var label: String {
            switch self {
            case .hours:  return String(localized: "Hours")
            case .days:   return String(localized: "Days")
            case .months: return String(localized: "Months")
            case .years:  return String(localized: "Years")
            }
        }

        /// Scrub units per full lap of the dial.
        var unitsPerLap: Int {
            switch self {
            case .hours:  return 24 * 60   // unit = 1 minute → lap = 1 day
            case .days:   return 30        // unit = 1 day    → lap ≈ 1 month
            case .months: return 12        // unit = 1 month  → lap = 1 year
            case .years:  return 12        // unit = 1 year   → lap = 12 years
            }
        }

        /// Rim tick count — the visible detents per lap.
        var ticks: Int {
            switch self {
            case .hours:  return 24
            case .days:   return 30
            case .months: return 12
            case .years:  return 12
            }
        }

        /// Scrub units per haptic detent (hours gear ticks per hour, not
        /// per minute).
        var unitsPerDetent: Int { self == .hours ? 60 : 1 }

        /// Calendar-aware advance — months/years clamp day-of-month
        /// legally via `Calendar`.
        func advance(_ date: Date, by units: Int) -> Date {
            let cal = Calendar.current
            switch self {
            case .hours:  return date.addingTimeInterval(TimeInterval(units * 60))
            case .days:   return cal.date(byAdding: .day,   value: units, to: date) ?? date
            case .months: return cal.date(byAdding: .month, value: units, to: date) ?? date
            case .years:  return cal.date(byAdding: .year,  value: units, to: date) ?? date
            }
        }
    }

    // MARK: State

    @State private var gear: Gear = .hours
    /// Visual spin of the tick ring (radians, unbounded).
    @State private var wheelAngle: Double = 0
    /// Last touch angle — nil between drags.
    @State private var lastAngle: Double? = nil
    /// Fractional scrub units not yet applied.
    @State private var pendingUnits: Double = 0
    /// Units accumulated toward the next haptic detent.
    @State private var detentAccum: Double = 0
    /// Last measured angular velocity (rad/s) for the release fling.
    @State private var angularVelocity: Double = 0
    @State private var lastDragTime: Date = .distantPast
    @State private var inertiaTask: Task<Void, Never>? = nil

    // ▼ TWEAK the crown feel here ▼
    private let diameter:   CGFloat = 240
    private let flingTau:   Double  = 0.7   // coast decay time constant
    private let flingMin:   Double  = 0.8   // rad/s to trigger a coast
    private let flingCap:   Double  = 12    // rad/s max spin

    private let detentTick = UIImpactFeedbackGenerator(style: .light)
    private let gearTick   = UIImpactFeedbackGenerator(style: .medium)

    // MARK: Body

    var body: some View {
        ZStack {
            // The glass disc — the crown face.
            Color.clear
                .frame(width: diameter, height: diameter)
                .glassEffect(.regular.interactive(), in: .circle)

            // Tick ring, spinning under the finger.
            tickRing
                .rotationEffect(.radians(wheelAngle))

            // Fixed 12-o'clock index the ticks sweep past.
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 3, height: 12)
                .offset(y: -diameter / 2 + 17)

            // Gear chips — the crown's pull-out positions, worn as a
            // centre complication.
            gearChips
        }
        .frame(width: diameter, height: diameter)
        .contentShape(.circle)
        .gesture(dragGesture)
        .onDisappear { inertiaTask?.cancel() }
    }

    // MARK: Ring

    private var tickRing: some View {
        let n = gear.ticks
        return ZStack {
            ForEach(0 ..< n, id: \.self) { i in
                Capsule()
                    .fill(.primary.opacity(0.45))
                    .frame(width: 2, height: 10)
                    .offset(y: -diameter / 2 + 18)
                    .rotationEffect(.radians(Double(i) / Double(n) * 2 * .pi))
            }
        }
        .animation(.snappy(duration: 0.25), value: n)
    }

    // MARK: Gear chips

    private var gearChips: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) { chip(.hours);  chip(.days)  }
            HStack(spacing: 10) { chip(.months); chip(.years) }
        }
    }

    private func chip(_ g: Gear) -> some View {
        Button {
            gearTick.impactOccurred()
            withAnimation(.snappy(duration: 0.2)) { gear = g }
            pendingUnits = 0
            detentAccum  = 0
        } label: {
            Text(g.label)
                .font(.caption.weight(gear == g ? .bold : .regular))
                .foregroundStyle(gear == g ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical,   4)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: Drag → time

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                inertiaTask?.cancel()
                inertiaTask = nil
                let c = diameter / 2
                let a = atan2(v.location.y - c, v.location.x - c)
                guard let last = lastAngle else {
                    lastAngle    = a
                    lastDragTime = .now
                    return
                }
                let d = Self.wrapPi(a - last)
                lastAngle = a
                let now = Date.now
                let dt  = now.timeIntervalSince(lastDragTime)
                if dt > 0 { angularVelocity = d / dt }
                lastDragTime = now
                apply(delta: d)
            }
            .onEnded { _ in
                lastAngle = nil
                startCoast()
            }
    }

    /// Turn an angular delta into whole scrub units (fraction banked in
    /// `pendingUnits`), advance the observation date, and tick the detents.
    /// Steps are applied UN-animated — the per-step snap IS the wheel feel,
    /// and the sky redraw per step is the live preview.
    private func apply(delta d: Double) {
        wheelAngle   += d
        pendingUnits += d / (2 * .pi) * Double(gear.unitsPerLap)
        let whole = Int(pendingUnits)
        guard whole != 0 else { return }
        pendingUnits -= Double(whole)

        state.setObservationDate(gear.advance(state.observationDate, by: whole),
                                 animated: false)

        detentAccum += Double(whole)
        let per = Double(gear.unitsPerDetent)
        if abs(detentAccum) >= per {
            detentTick.impactOccurred(intensity: 0.6)
            detentAccum.formTruncatingRemainder(dividingBy: per)
        }
    }

    /// iPod-wheel coast: keep spinning after release, decaying
    /// exponentially, still stepping (and ticking) through `apply`.
    private func startCoast() {
        let v0 = angularVelocity
        angularVelocity = 0
        guard abs(v0) > flingMin else { return }
        inertiaTask = Task { @MainActor in
            var v    = min(max(v0, -flingCap), flingCap)
            var last = Date.now
            while !Task.isCancelled, abs(v) > 0.15 {
                try? await Task.sleep(nanoseconds: 16_000_000)
                let now = Date.now
                let dt  = now.timeIntervalSince(last)
                last = now
                apply(delta: v * dt)
                v *= exp(-dt / flingTau)
            }
        }
    }

    private static func wrapPi(_ a: Double) -> Double {
        var x = a.truncatingRemainder(dividingBy: 2 * .pi)
        if x >  .pi { x -= 2 * .pi }
        if x < -.pi { x += 2 * .pi }
        return x
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        DateCrown()
            .environment(EAppState())
    }
}

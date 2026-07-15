import SwiftUI
import LoreKit

// MARK: - DateCrown
// The time-travel instrument: a glass ring RESTING ON THE HORIZON. When the
// date picker presents, the camera glides home to the default framing and
// this annulus lands exactly on the horizon circle (NorthIN) — or the
// tropic (NorthOUT): `northOutDefaultScale` is derived so the tropic sits
// at the same screen radius (ρ_tropic · northOutScale ≡ 2 · defaultScale),
// so the ring is ONE circle on screen and what changes is which celestial
// line it embodies. You grab the boundary of your sky and turn time.
//
// Drag around the ring like an iPod wheel — the sky inside is the live
// preview (and stays touchable through the hole; the hit area is the donut
// only). Flick to coast; every detent ticks.
//
// Gear positions (shifted from the panel's segmented control):
//
//   • Hours  — one lap = one day (one turn of the ring = one turn of the
//              sky, which is physically true). Scrubs by the minute,
//              ticks by the hour.
//   • Days   — one lap = 30 days; click per day, time-of-day held, so you
//              compare "same hour, night after night" (moon phases roll).
//   • Months — one lap = 12 months: the ring becomes the year-circle
//              (the zodiac wheel). Click per month.
//   • Years  — one lap = 12 years (≈ one Jupiter orbit). Click per year.
//
// Whole-unit stepping is deliberate — it keeps the wheel-picker's
// comparability (click, click, watch the sky change).
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

        /// Scrub units per full lap of the ring.
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

        /// Scrub units per haptic detent. Hours clicks per QUARTER-hour —
        /// 96 detents/lap, the dense iPod ratchet (the engine keeps up now;
        /// see CrownHaptics). ▼ TWEAK: 60 = hourly, 15 = iPod-dense ▼
        var unitsPerDetent: Int { self == .hours ? 15 : 1 }

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

    /// Centreline radius (screen pt) — the horizon circle: 2 · defaultScale.
    /// The panel computes it so the ring rests on the cartography.
    let radius: CGFloat
    /// The active gear — owned by the panel (its segmented control shifts
    /// it), bound in so the ring and the control stay one instrument.
    @Binding var gear: Gear

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

    // ▼ TWEAK the ring feel here ▼
    private let ringWidth: CGFloat = 24    // thumb-band width
    private let flingTau:  Double  = 0.7   // coast decay time constant
    private let flingMin:  Double  = 0.8   // rad/s to trigger a coast
    private let flingCap:  Double  = 12    // rad/s max spin

    private var labelText: String {
        let date = state.observationDate
        let components = Calendar.current.dateComponents([.hour, .day, .month, .year], from: date)
        
        switch gear {
        case .hours:
            return components.hour?.description ?? ""
        case .days:
            return components.day?.description ?? ""
        case .months:
            return components.month?.description ?? ""
        case .years:
            return components.year?.description ?? ""
        }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let ringRadius = 2*radius + ringWidth/2
            
            GlassEffectContainer {
            ZStack {
                
                    GlassRing(
                        thickness: ringWidth,
                        corners: gear.ticks,
                        bulge: 2.3,
                        rotation: .radians(wheelAngle)
                    )
                    .shadow(radius: 6)
                    .frame(
                        width : ringRadius,
                        height: ringRadius
                    )
                }
            }
            .position(c)
            // Hit area = the band only. Taps and pans INSIDE the ring fall
            // through to the sky; the map stays live while you scrub time.
            .contentShape(Annulus(centre: c,
                                  radius: radius,
                                  width:  ringWidth + 12), eoFill: true)
            .gesture(dragGesture(centre: c))
        }
        // Gear shifted (externally, via the panel's segmented control) →
        // drop banked fractions so the new ratio starts clean.
        .onChange(of: gear) { _, _ in
            pendingUnits = 0
            detentAccum  = 0
        }
        .onDisappear {
            inertiaTask?.cancel()
            state.isScrubbingDate = false
        }
    }

    // MARK: Ring ticks

    private var tickRing: some View {
        let n = gear.ticks
        return ZStack {
            ForEach(0 ..< n, id: \.self) { i in
                Capsule()
                    .fill(.secondary)
                    .frame(width: 2, height: 16)
                    .offset(y: -radius + ringWidth/4)
                    .rotationEffect(.radians(Double(i) / Double(n) * 2 * .pi))
            }
        }
        .animation(.snappy(duration: 0.25), value: n)
    }

    // MARK: Donut hit shape

    /// Annulus path (even-odd) centred on `centre` — the ring band plus a
    /// little grab margin, so the hole stays transparent to touches.
    private struct Annulus: Shape {
        let centre: CGPoint
        let radius: CGFloat
        let width:  CGFloat
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let ro = radius + width / 2
            let ri = max(0, radius - width / 2)
            p.addEllipse(in: CGRect(x: centre.x - ro, y: centre.y - ro,
                                    width: ro * 2, height: ro * 2))
            p.addEllipse(in: CGRect(x: centre.x - ri, y: centre.y - ri,
                                    width: ri * 2, height: ri * 2))
            return p
        }
    }

    // MARK: Drag → time

    private func dragGesture(centre c: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                inertiaTask?.cancel()
                inertiaTask = nil
                if !state.isScrubbingDate { state.isScrubbingDate = true }  // eye → the pill
                let a = atan2(v.location.y - c.y, v.location.x - c.x)
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
                apply(delta: d, over: max(dt, 0.008))
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
    ///
    /// Haptics: count EVERY detent this frame crossed (the old code fired at
    /// most one per frame and swallowed the rest — why fast spins went
    /// silent) and hand the batch to `CrownHaptics`, which schedules them as
    /// CoreHaptics transients spread across the frame — the iPod ratchet.
    private func apply(delta d: Double, over window: TimeInterval) {
        wheelAngle   += d
        pendingUnits += d / (2 * .pi) * Double(gear.unitsPerLap)
        let whole = Int(pendingUnits)
        guard whole != 0 else { return }
        pendingUnits -= Double(whole)

        state.setObservationDate(gear.advance(state.observationDate, by: whole),
                                 animated: false)

        detentAccum += Double(whole)
        let per     = Double(gear.unitsPerDetent)
        let crossed = Int(abs(detentAccum) / per)
        if crossed > 0 {
            detentAccum.formTruncatingRemainder(dividingBy: per)
            let rate = window > 0 ? Double(crossed) / window : 0
            CrownHaptics.shared.tick(count: crossed, window: window, rate: rate)
        }
    }

    /// iPod-wheel coast: keep spinning after release, decaying
    /// exponentially, still stepping (and ticking) through `apply`. The
    /// scrub emphasis (`isScrubbingDate`) rides the whole spin — it releases
    /// only once the wheel actually stops, so the pill settles with it.
    private func startCoast() {
        let v0 = angularVelocity
        angularVelocity = 0
        guard abs(v0) > flingMin else {
            state.isScrubbingDate = false                // no coast → settle now
            return
        }
        inertiaTask = Task { @MainActor in
            var v    = min(max(v0, -flingCap), flingCap)
            var last = Date.now
            while !Task.isCancelled, abs(v) > 0.15 {
                try? await Task.sleep(nanoseconds: 16_000_000)
                let now = Date.now
                let dt  = now.timeIntervalSince(last)
                last = now
                apply(delta: v * dt, over: dt)
                v *= exp(-dt / flingTau)
            }
            // Don't clear if a fresh drag interrupted us (it re-set the flag).
            if !Task.isCancelled { state.isScrubbingDate = false }
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
        DateCrown(radius: 170, gear: .constant(.hours))
            .environment(EAppState())
    }
}

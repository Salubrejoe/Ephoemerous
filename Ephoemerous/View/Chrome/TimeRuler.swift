import SwiftUI

// MARK: - TimeRuler
// The time-travel control: a horizontal ruler you slide like film under a
// fixed centre mark. Drag the tape LEFT to travel into the future (the
// days to come slide in from the right), RIGHT into the past. The scale
// is the panel's segmented picker — Hours · Days · Months · Years — so the
// unit is chosen, never guessed.
//
// Every tick is one step of the scale; the long ticks mark its natural
// group (the hour, the week, the year, the decade). Each step clicks
// (`CrownHaptics`); a flick coasts on, slowing to a stop.
//
// It lives below the sky, so whatever stands in the middle — the Orloj,
// the bare chart — is only ever the live preview, never a competing dial.
struct TimeRuler: View {

    @Environment(AppState.self) private var state

    /// The scale — the panel's picker. Reuses the ring's gears.
    let gear: DateCrown.Gear

    // ▼ TWEAK the tape ▼
    private let height:   CGFloat = 44
    private let flingTau: Double  = 0.5

    /// Finger travel not yet turned into whole steps.
    @State private var pending: CGFloat = 0
    /// The tape's slide, for drawing the ticks.
    @State private var slide:   CGFloat = 0
    @State private var lastX:   CGFloat? = nil
    @State private var lastTime: Date = .distantPast
    /// Smoothed finger speed (pt/s, + = toward the future).
    @State private var speed:   CGFloat = 0
    @State private var coast:   Task<Void, Never>? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ticks(width: geo.size.width)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                                                 .init(color: .black, location: 0.15),
                                                 .init(color: .black, location: 0.85),
                                                 .init(color: .clear, location: 1)],
                                         startPoint: .leading, endPoint: .trailing))
                // The fixed mark — now, wherever the tape has slid to.
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: height - 12)
            }
            .frame(width: geo.size.width, height: height)
        }
        .frame(height: height)
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(.capsule)
        .gesture(drag)
        .onChange(of: gear) { _, _ in pending = 0 }
        .onDisappear {
            coast?.cancel()
            state.isScrubbingDate = false
        }
    }

    // MARK: Tape

    /// Points of tape per step of the scale. ▼ TWEAK ▼
    private var spacing: CGFloat {
        switch gear {
        case .hours:  return 9      // a quarter hour
        case .days:   return 14     // a day
        case .months: return 22     // a month
        case .years:  return 26     // a year
        }
    }

    /// Steps per long tick: the hour, the week, the year, the decade.
    private var group: Int {
        switch gear {
        case .hours:  return 4
        case .days:   return 7
        case .months: return 12
        case .years:  return 10
        }
    }

    private func ticks(width: CGFloat) -> some View {
        Canvas { ctx, size in
            let mid   = size.width / 2
            let first = Int(((-mid - slide) / spacing).rounded(.down)) - 1
            let last  = Int(((mid - slide) / spacing).rounded(.up)) + 1
            for i in first...last {
                let x     = mid + slide + CGFloat(i) * spacing
                let major = ((i % group) + group) % group == 0
                let h: CGFloat = major ? 18 : 9
                let rect  = CGRect(x: x - 0.5, y: (size.height - h) / 2, width: 1, height: h)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 0.5),
                         with: .color(.primary.opacity(major ? 0.7 : 0.35)))
            }
        }
    }

    // MARK: Gesture

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                coast?.cancel(); coast = nil
                if !state.isScrubbingDate { state.isScrubbingDate = true }
                let now = Date.now
                guard let last = lastX else {
                    lastX = v.location.x; lastTime = now
                    return
                }
                let dx = v.location.x - last
                let dt = max(now.timeIntervalSince(lastTime), 0.008)
                lastX = v.location.x; lastTime = now
                speed = 0.7 * speed + 0.3 * (-dx) / CGFloat(dt)
                move(by: dx, over: dt)
            }
            .onEnded { _ in
                lastX = nil
                startCoast()
            }
    }

    /// Slide the tape and turn its travel into whole steps — leftward is
    /// the future.
    private func move(by dx: CGFloat, over dt: TimeInterval) {
        slide   += dx
        pending -= dx
        let steps = Int(pending / spacing)
        guard steps != 0 else { return }
        pending -= CGFloat(steps) * spacing
        state.setObservationDate(advance(state.observationDate, by: steps), animated: false)
        let n = abs(steps)
        CrownHaptics.shared.tick(count: n, window: dt, rate: Double(n) / dt)
    }

    /// One step of the scale: a quarter hour, a day, a month, a year.
    private func advance(_ date: Date, by steps: Int) -> Date {
        gear == .hours ? date.addingTimeInterval(TimeInterval(steps * 15 * 60))
                       : gear.advance(date, by: steps)
    }

    /// A flick coasts on, slowing exponentially.
    private func startCoast() {
        var v = speed
        speed = 0
        guard abs(v) > 120 else { settle(); return }
        coast = Task { @MainActor in
            var last = Date.now
            while !Task.isCancelled, abs(v) > 30 {
                try? await Task.sleep(for: .milliseconds(16))
                let now = Date.now
                let dt  = now.timeIntervalSince(last)
                last = now
                move(by: -v * CGFloat(dt), over: dt)
                v *= CGFloat(exp(-dt / flingTau))
            }
            if !Task.isCancelled { settle() }
        }
    }

    private func settle() {
        pending = 0
        state.isScrubbingDate = false
    }
}

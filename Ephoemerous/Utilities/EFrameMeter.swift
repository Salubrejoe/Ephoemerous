import SwiftUI
import QuartzCore

// MARK: - EFrameMeter
// Lightweight canvas frame-time probe for on-device perf testing where
// Instruments can't reach (TestFlight). The canvas reports the start of
// each draw pass; the meter derives:
//
//   • fps    — draw passes per second (the *effective* canvas rate,
//              which under a 60 Hz schedule should sit near 60 during
//              gestures and 0 when parked)
//   • avgMs  — mean CPU cost of a draw pass in the window
//   • maxMs  — worst pass in the window (the stutter signature: a
//              healthy avg with ugly spikes = periodic hitches)
//
// Accumulation happens in ObservationIgnored scratch — recording a
// frame never invalidates anything. The observable display values are
// published twice a second via an async hop (the canvas closure runs
// inside a view update, where synchronous observable writes are
// illegal), so the HUD re-renders at 2 Hz regardless of frame rate.
@Observable
final class EFrameMeter {

    static let shared = EFrameMeter()
    private init() {}

    // MARK: Published (2 Hz)

    private(set) var fps:    Double = 0
    private(set) var avgMs:  Double = 0
    private(set) var maxMs:  Double = 0
    /// True when no draw pass has landed for ~0.7 s — the parked idle
    /// canvas. Seeing this flip on device proves the park works there.
    private(set) var parked: Bool   = true

    // MARK: Scratch (never observed)

    @ObservationIgnored private var lastStart:   Double = 0
    @ObservationIgnored private var windowStart: Double = 0
    @ObservationIgnored private var frames:      Int    = 0
    @ObservationIgnored private var costSum:     Double = 0
    @ObservationIgnored private var costMax:     Double = 0
    @ObservationIgnored private var parkTask:    Task<Void, Never>? = nil

    /// Call at the END of a canvas draw pass, with the
    /// `CACurrentMediaTime()` captured as its first line.
    func record(frameStart t0: Double) {
        let now  = CACurrentMediaTime()
        let cost = (now - t0) * 1000

        // A long gap means the canvas was parked — start a fresh window
        // so the first frame back isn't averaged against the silence.
        if t0 - lastStart > 0.5 {
            windowStart = t0
            frames = 0; costSum = 0; costMax = 0
        }
        lastStart = t0

        frames  += 1
        costSum += cost
        costMax  = Swift.max(costMax, cost)

        let window = now - windowStart
        guard window >= 0.5, frames > 0 else { return }

        let f   = Double(frames) / window
        let avg = costSum / Double(frames)
        let mx  = costMax
        windowStart = now
        frames = 0; costSum = 0; costMax = 0

        DispatchQueue.main.async {
            self.fps    = f
            self.avgMs  = avg
            self.maxMs  = mx
            self.parked = false
            self.armParkCheck()
        }
    }

    /// Flip to "parked" if no window flushes for a while.
    private func armParkCheck() {
        parkTask?.cancel()
        parkTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self.parked = true
        }
    }
}

// MARK: - FrameMeterHUD
// Tiny glanceable readout — "59 fps  4.2 ms  ↑9.8" — tinted by the
// worst frame in the window against the 60 Hz budget. Hit-testing off:
// it's a probe, not a control.
struct FrameMeterHUD: View {

    private let meter = EFrameMeter.shared

    var body: some View {
        Group {
            if meter.parked {
                Text(verbatim: "parked")
                    .foregroundStyle(.secondary)
            } else {
                Text(verbatim: String(format: "%.0f fps  %.1f ms  ↑%.1f",
                                      meter.fps, meter.avgMs, meter.maxMs))
                    .foregroundStyle(tint)
            }
        }
        .font(.caption2.weight(.semibold))
        .monospacedDigit()
        .padding(.horizontal, 10)
        .padding(.vertical,   5)
        .background(.ultraThinMaterial, in: .capsule)
        .allowsHitTesting(false)
    }

    /// Green inside the 120 Hz budget, orange inside 60 Hz, red beyond —
    /// judged on the WORST frame, because stutter is spikes, not means.
    private var tint: Color {
        switch meter.maxMs {
        case ..<8.3:  .green
        case ..<16.6: .orange
        default:      .red
        }
    }
}

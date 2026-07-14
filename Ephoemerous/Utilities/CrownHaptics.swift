import CoreHaptics
import UIKit
import AudioToolbox

// MARK: - CrownHaptics
// The iPod click-wheel ratchet for the date crown. `UIImpactFeedbackGenerator`
// can't do this — each impact is a heavyweight one-shot the Taptic Engine
// coalesces and drops past ~20/s, which is why fast spins went silent.
// CoreHaptics can: a single pattern carries N TRANSIENT events at sub-frame
// offsets, so one frame that crossed five detents plays five distinct clicks
// spread across its own duration — a true ratchet up to buzz speed.
//
// Character: clicks get LIGHTER as the rate climbs (the iPod feel — slow
// deliberate clicks are weighty, a flick is a fizz). Falls back to
// `UISelectionFeedbackGenerator` (the picker-wheel tick) on hardware
// without CoreHaptics.
@MainActor
final class CrownHaptics {

    static let shared = CrownHaptics()

    private var engine: CHHapticEngine?
    private let fallback = UISelectionFeedbackGenerator()

    // ▼ TWEAK the ratchet character here ▼
    /// Max clicks scheduled per frame — beyond this a spin reads as texture,
    /// not clicks, and extra events are wasted engine load.
    private let maxPerFrame = 6
    /// Intensity ramp: full-weight click when slow, floor when spinning.
    private let slowIntensity: Float = 0.9
    private let fastIntensity: Float = 0.35
    /// Detents/second at which the ramp bottoms out.
    private let fastRate: Double = 100
    /// Click crispness (0 dull thud … 1 sharp tick).
    private let sharpness: Float = 0.6
    /// The iPod CLICKER — the keyboard "tock" (system sound 1104) alongside
    /// the taps. Rate-limited: audio clicks blur past ~25/s anyway, so one
    /// tock per limited window carries the sound while the haptic carries
    /// the count. Respects the ringer switch, like the original.
    private let clickerEnabled = true
    private let clickerMinGap: TimeInterval = 0.04
    private var lastClick: Date = .distantPast

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        // Auto-shutdown manages start/stop around playback — no lifecycle
        // bookkeeping, survives backgrounding.
        engine?.isAutoShutdownEnabled = true
        fallback.prepare()
    }

    /// Play `count` ratchet clicks for a frame that crossed that many
    /// detents, spread across `window` seconds (that frame's duration), at
    /// `rate` detents/second.
    func tick(count: Int, window: TimeInterval, rate: Double) {
        guard count > 0 else { return }

        // The clicker rides every path (CoreHaptics or fallback).
        if clickerEnabled, Date.now.timeIntervalSince(lastClick) > clickerMinGap {
            AudioServicesPlaySystemSound(1104)      // keyboard tock
            lastClick = .now
        }

        guard let engine else {                      // no CoreHaptics → picker tick
            fallback.selectionChanged()
            fallback.prepare()
            return
        }

        let n = min(count, maxPerFrame)
        let intensity = max(fastIntensity,
                            slowIntensity - Float(rate / fastRate)
                                * (slowIntensity - fastIntensity))
        // Spread the clicks across the frame that earned them, so a
        // 3-detent frame sounds like click-click-click, not one thump.
        let step = max(window, 1.0 / 60) / Double(n)

        let events = (0 ..< n).map { i in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ],
                relativeTime: Double(i) * step
            )
        }

        guard let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player  = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}

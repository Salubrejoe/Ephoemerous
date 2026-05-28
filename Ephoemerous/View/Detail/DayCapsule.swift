import SwiftUI
import LoreKit

// MARK: - DayCapsule
// 24-hour "day-glance" capsule that sits in the same layout slot
// (and shares the exact shape + height) as `RememberButton`.
// Visually it's just a wide rounded pill filled with a continuous
// midnight → dawn → noon → dusk → midnight gradient, with optional
// event dots positioned along its width by time-of-day fraction
// (0h on the left edge, 24h on the right).
//
// Function-only-later: today this is a pure read-out — the eventual
// "drag to scrub the canvas through time" slider behaviour will be
// layered on once the visual lands.
struct DayCapsule: View {

    /// One event marker on the capsule — a time, a description for
    /// accessibility / future tooltips, and the dot's fill.
    struct Event: Identifiable {
        let id    = UUID()
        let time:  Date
        let label: String
        let color: Color
    }

    let events:   [Event]
    let gradient: LinearGradient

    init(events: [Event], gradient: LinearGradient = .dayCapsuleSun) {
        self.events   = events
        self.gradient = gradient
    }

    /// Locked to the same height as RememberButton's intrinsic
    /// height (semibold body text + 14pt vertical padding) so the
    /// two components are interchangeable in the layout slot under
    /// the header.
    private var capsuleHeight: CGFloat { 50 }

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
            }
        }
        .frame(height: capsuleHeight)
    }

    /// Map a `Date` to an x-coordinate along the capsule. Uses the
    /// current calendar's wall-clock hour + minute, so the position
    /// reads as the local time-of-day regardless of timezone.
    private func x(for time: Date, width: CGFloat) -> CGFloat {
        let cal     = Calendar.current
        let comps   = cal.dateComponents([.hour, .minute, .second], from: time)
        let seconds = (comps.hour ?? 0) * 3600
                    + (comps.minute ?? 0) * 60
                    + (comps.second ?? 0)
        let fraction = Double(seconds) / 86_400.0
        return CGFloat(fraction) * width
    }
}

// MARK: - Gradient palettes
// One source of truth for the two timeline palettes used today.
// Both are pastel by design — the capsule sits next to a saturated
// RememberButton in some layouts, and is the only colour body in
// others, so values stay low-chroma so they don't shout.
extension LinearGradient {

    /// Sun's 24h: dusty indigo at midnight → pale peach at dawn →
    /// cream at noon → dusty apricot at dusk → dusty indigo back at
    /// midnight. Anchored at 0 / 25 / 50 / 75 / 100% of the capsule
    /// width.
    static let dayCapsuleSun: LinearGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.22, green: 0.22, blue: 0.36), location: 0.00),
            .init(color: Color(red: 0.94, green: 0.80, blue: 0.74), location: 0.25),
            .init(color: Color(red: 0.99, green: 0.94, blue: 0.78), location: 0.50),
            .init(color: Color(red: 0.94, green: 0.74, blue: 0.58), location: 0.75),
            .init(color: Color(red: 0.22, green: 0.22, blue: 0.36), location: 1.00),
        ]),
        startPoint: .leading,
        endPoint:   .trailing
    )

    /// Moon's 24h: deep indigo at midnight (peak moon visibility),
    /// pale lavender through dawn / dusk, pale silver-grey at noon
    /// (moon washed out by the sun). Reads as moonlight rising and
    /// falling rather than sunlight.
    static let dayCapsuleMoon: LinearGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.20, green: 0.22, blue: 0.40), location: 0.00),
            .init(color: Color(red: 0.62, green: 0.66, blue: 0.80), location: 0.25),
            .init(color: Color(red: 0.86, green: 0.88, blue: 0.93), location: 0.50),
            .init(color: Color(red: 0.62, green: 0.66, blue: 0.80), location: 0.75),
            .init(color: Color(red: 0.20, green: 0.22, blue: 0.40), location: 1.00),
        ]),
        startPoint: .leading,
        endPoint:   .trailing
    )
}

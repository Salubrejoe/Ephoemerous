import SwiftUI

// MARK: - EphoemerousWatch
// The Orloj on the wrist: the SAME face the iOS widget renders
// (`OrlojFace` + `OrlojFaceLayers`, shared sources) filling the watch
// screen — and the Digital Crown as the time machine. Turn the crown to
// travel hours and days: the rete spins, the hands sweep, the unequal
// hours breathe with the seasons. Tap to come home to Now.
//
// The observer origin comes from the shared FavouritesStore; on the
// watch its app-group defaults are empty until a sync story exists, so
// the face falls back to Prague — fitting, for this face.
@main
struct EphoemerousWatchApp: App {
    var body: some Scene {
        WindowGroup {
            OrlojWatchView()
        }
    }
}


// MARK: - OrlojWatchView
struct OrlojWatchView: View {

    /// Crown position — HOURS away from now. A quarter-hour detent per
    /// step; range ± one year. ▼ TWEAK the time-travel feel here ▼
    @State private var crownHours: Double = 0
    @FocusState private var crownFocused: Bool

    /// Travelling = the crown has left Now by at least its own step.
    private var isTravelling: Bool { abs(crownHours) >= 0.25 }

    /// "Wed 22 Jul, 03:15" — the destination readout while travelling.
    private static let travelFormat: Date.FormatStyle =
        .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        .hour(.defaultDigits(amPM: .abbreviated)).minute()

    var body: some View {
        // Ticks every minute at rest so the face stays honest on the
        // wrist; the crown offset rides on top of the live base.
        TimelineView(.everyMinute) { timeline in
            let date = timeline.date.addingTimeInterval(crownHours * 3600)

            GeometryReader { geo in
                // ▼ TWEAK the wrist brightness here — 1 = the widget's
                // postcard inks; the small OLED wants more. ▼
                OrlojFaceLayers(face: OrlojFace(date:   date,
                                                origin: FavouritesStore().observerOrigin(),
                                                size:   geo.size),
                                brilliance: 1.9)
            }
            .overlay(alignment: .bottom) {
                if isTravelling {
                    // Destination pill — the app's chrome voice (rounded,
                    // glassy). Tap anywhere springs back to Now.
                    Text(date, format: Self.travelFormat)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical,   4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 2)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
//        .background(Artist.shared.canvasBackground)
        .preferredColorScheme(.dark)
        // The crown IS the date crown here. Haptic detents; not
        // continuous — the journey has ends, like the app's timeline.
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation($crownHours,
                              from:        -24 * 366,
                              through:      24 * 366,
                              by:           0.25,
                              sensitivity: .medium,
                              isContinuous: false,
                              isHapticFeedbackEnabled: true)
        .onAppear { crownFocused = true }
        .onTapGesture {
            withAnimation(.snappy(duration: 0.3)) { crownHours = 0 }
        }
        .animation(.easeInOut(duration: 0.2), value: isTravelling)
    }
}

#Preview {
    OrlojWatchView()
}

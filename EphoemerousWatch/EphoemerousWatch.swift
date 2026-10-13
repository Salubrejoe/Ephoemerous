import SwiftUI

// MARK: - EphoemerousWatch
// The Orloj on the wrist: the SAME glass face the iOS widget renders
// (`OrlojFace` + `OrlojGlassLayers`, shared sources) filling the watch
// screen — and the Digital Crown as the time machine. Turn the crown to
// travel hours and days: the rete spins, the hands sweep, the planets
// ride the band. Tap to come home to Now.
//
// The observer origin comes from the shared FavouritesStore; on the
// watch its app-group defaults are empty until a sync story exists, so
// the face falls back to Prague — fitting, for this face.
@main
struct EphoemerousWatchApp: App {
    var body: some Scene {
        WindowGroup {
            // The face IS the clock, so the system's time in the corner
            // goes. `_statusBarHidden` is public SwiftUI (watchOS 6+), the
            // one switch watchOS honours for it; `persistentSystemOverlays`
            // and a hidden navigation bar both left the time up.
            OrlojWatchView()
                ._statusBarHidden()
        }
    }
}


// MARK: - OrlojWatchView
// The glass is dear to draw — drawn live, the first frame alone ran past
// watchOS's ten-second launch watchdog, and even unfrosted it lagged the
// crown. But time travel only TURNS things about the axle: the sky and
// the rete at the sidereal rate, each hand at its body's, the dial not at
// all. So the face is rendered as five pictures (see `OrlojParts`), and
// while the crown travels the watch only turns them. They're redrawn only
// once the crown rests AND the face has travelled far enough that the
// Sun, Moon and planets have moved along.
struct OrlojWatchView: View {

    /// Crown position — HOURS away from now. A quarter-hour detent per
    /// step; range ± one year. ▼ TWEAK the time-travel feel here ▼
    @State private var crownHours: Double = 0
    @FocusState private var crownFocused: Bool

    /// The face's parts as last rendered.
    @State private var drawn: Drawn?
    @Environment(\.displayScale) private var displayScale

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
                ZStack {
                    if let drawn {
                        ForEach(drawn.parts.indices, id: \.self) { i in
                            Image(decorative: drawn.parts[i].image, scale: displayScale)
                                .rotationEffect(drawn.turn(drawn.parts[i].part, to: date),
                                                anchor: drawn.axle)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .task(id: Frame(date: date, size: geo.size)) {
                    // Turning the pictures is true for hours either side;
                    // only past that — the Sun, Moon and planets have
                    // moved along — and only once the crown truly rests,
                    // render afresh. A turn of the crown cancels it.
                    if let drawn {
                        guard drawn.size != geo.size
                              || abs(date.timeIntervalSince(drawn.date)) > Self.drift
                        else { return }
                        try? await Task.sleep(for: Self.rest)
                        guard !Task.isCancelled else { return }
                    }
                    await render(date: date, size: geo.size)
                }
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
        // The ground the Orloj widget stands on — the deep sky.
        .background(WidgetColourTrial.orlojGround.ignoresSafeArea())
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

    /// The glass lifted for the small OLED (see `OrlojGlassLayers.brilliance`).
    /// ▼ TWEAK ▼
    private static let brilliance: Double = 1.3

    /// The small widget's face at the wrist's size.
    private func face(_ date: Date, _ size: CGSize) -> OrlojFace {
        OrlojFace(date: date, origin: FavouritesStore().observerOrigin(), size: size)
    }

    /// How far the pictures may be turned before they're redrawn, and how
    /// long the crown must rest first. ▼ TWEAK ▼
    private static let drift: TimeInterval = 3 * 3600
    private static let rest:  Duration     = .milliseconds(1500)

    /// The face's five parts, each into a bitmap of the whole screen — one
    /// at a time, stepping aside between them so the crown stays live;
    /// they swap in only when all five are done.
    private func render(date: Date, size: CGSize) async {
        guard size.width > 0, size.height > 0 else { return }
        let face  = face(date, size)
        let parts: [OrlojParts] = [.sky, .dial, .rete, .moonHand, .sunHand]
        var images: [(part: OrlojParts, image: CGImage)] = []
        for part in parts {
            if drawn != nil {
                await Task.yield()
                guard !Task.isCancelled else { return }
            }
            let renderer = ImageRenderer(content:
                OrlojGlassLayers(face: face, lean: true, brilliance: Self.brilliance,
                                 wrist: true, parts: part)
                    .frame(width: size.width, height: size.height)
                    .environment(\.colorScheme, .dark))
            renderer.scale = displayScale
            if let image = renderer.cgImage { images.append((part, image)) }
        }
        // The axle — the wrist face fills the screen, no breath.
        let mid  = CGPoint(x: size.width / 2, y: size.height / 2)
        let axle = face.center
        drawn = Drawn(parts: images, date: date, size: size, sense: face.hourSense,
                      axle: UnitPoint(x: axle.x / size.width, y: axle.y / size.height))
    }

    /// The parts as rendered, and how far each turns by another moment.
    private struct Drawn {
        let parts: [(part: OrlojParts, image: CGImage)]
        let date:  Date
        let size:  CGSize
        let sense: Double
        let axle:  UnitPoint

        /// Seconds per turn of the sky, the Sun's hand and the Moon's.
        private static let sidereal = 86_164.1, solar = 86_400.0, lunar = 89_428.3

        func turn(_ part: OrlojParts, to date: Date) -> Angle {
            let period: Double
            switch part {
            case .sky, .rete: period = Self.sidereal
            case .sunHand:    period = Self.solar
            case .moonHand:   period = Self.lunar
            default:          return .zero
            }
            return .radians(sense * 2 * .pi * date.timeIntervalSince(self.date) / period)
        }
    }

    private struct Frame: Equatable {
        let date: Date
        let size: CGSize
    }
}

#Preview {
    OrlojWatchView()
}

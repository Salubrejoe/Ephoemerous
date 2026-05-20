import SwiftUI
import UIKit
import CoreLocation


struct CelestialCanva: View {
    
    @Environment(EAppState.self) var state
    
    
    // MARK: - Layers
    // One unified celestial-content set drawn in both modes. EarthGrid +
    // Horizon ride the origin slerp (UL). Sun/Moon/Stars/Ecliptic/Planets/
    // SelectedStars stay celestially put (NS) so they don't smear during
    // the slerp. The chrome below brackets this content front and back.
    private let commonLayers: [any EGridLayer] = [
        EarthGridLayer(mode: .userLocation),
        HorizonLayer(),
        CardinalLabelsLayer(),
        EStarsLayer(mode: .northSouth),
        EclipticLayer(mode: .northSouth),
        ESunLayer(mode: .northSouth),
        EMoonLayer(mode: .northSouth),
        EPlanetsLayer(mode: .northSouth),
        ESelectedStarsLayer(mode: .northSouth),
    ]

    // Behind the celestial content — the watch-face disc fill.
    private let clockChromeBack: [any EGridLayer] = [
        WatchBackgroundLayer(),
    ]

    // In front of the celestial content — the hour numbers / clip ring.
    private let clockChromeFront: [any EGridLayer] = [
        ClipAndHoursLayer(),
    ]
    
    // Every touch interaction lives in the coordinator (own file / class).
    @State private var gestures = CelestialGestureCoordinator()

    // MARK: - Body

    var body: some View {
        // One timeline: 60 fps during gestures/transitions, 10 fps at rest.
        // `schedule` is recomputed whenever isAnimating flips, so TimelineView
        // reschedules on the next render — no destructive .id() teardown.
        TimelineView(schedule) { timeline in
            // Cross-fade opacities for the clock chrome and the travel
            // backdrop. At rest they collapse to {1, 0} or {0, 1}, so the
            // matching chrome canvas is skipped entirely.
            let clockA  = state.renderedClockOpacity
            let travelA = state.renderedTravelOpacity

            ZStack {
                // Travel backdrop — fades in opposite the clock chrome.
                if travelA > 0 {
                    Color.systemBackground.opacity(travelA)
                }

                // Back chrome (watch-face disc) — sits behind the celestial
                // content so the stars/grid show on top of the disc fill.
                if clockA > 0 {
                    Canvas { ctx, size in
                        var dc = EGraphicContext(ctx: ctx, size: size, state: state)
                        for layer in clockChromeBack { layer.draw(in: &dc) }
                    }
                    .opacity(clockA)
                }

                // Unified celestial content — drawn in both modes. Also
                // owns the per-frame canvas clock tick.
                Canvas { ctx, size in
                    state.advanceCanvasClock(
                        to:         timeline.date.timeIntervalSinceReferenceDate,
                        canvasSize: size
                    )
                    var dc = EGraphicContext(ctx: ctx, size: size, state: state)
                    for layer in commonLayers { layer.draw(in: &dc) }
                }

                // Front chrome (hour numbers) — drawn on top of the
                // celestial content, fades with the clock group.
                if clockA > 0 {
                    Canvas { ctx, size in
                        var dc = EGraphicContext(ctx: ctx, size: size, state: state)
                        for layer in clockChromeFront { layer.draw(in: &dc) }
                    }
                    .opacity(clockA)
                }

                // Topmost, sharp & interactive: owns every canvas touch.
                // The flexible frame keeps this coordinate space immune to
                // any sibling's intrinsic size.
                CelestialGestureView(gestures: gestures, state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .clipped()
    }
}

// MARK: - Schedule

// Switches between 60fps (gestures/transitions) and 10fps (idle).
struct ECanvasSchedule: TimelineSchedule {
    let isAnimating: Bool
    
    func entries(from start: Date, mode: Mode) -> Entries {
        Entries(isAnimating: isAnimating, start: start)
    }
    
    struct Entries: Sequence, IteratorProtocol {
        let isAnimating: Bool
        var next_date: Date
        init(isAnimating: Bool, start: Date) {
            self.isAnimating = isAnimating
            self.next_date   = start
        }
        mutating func next() -> Date? {
            let current   = next_date
            next_date     = isAnimating
            ? current.addingTimeInterval(1.0 / 60.0)
            : current.addingTimeInterval(1.0 / 10.0)
            return current
        }
    }
}

extension CelestialCanva {
    private var isAnimating: Bool {
        gestures.isInteracting          ||
        state._activeTransition  != nil ||
        state._dateTransition    != nil ||
        state._originTransition     != nil ||
        state._inertiaTransition    != nil ||
        state._projectionTransition != nil   // keep 60 fps while the fling/mode blend runs
    }
    private var schedule: ECanvasSchedule { ECanvasSchedule(isAnimating: isAnimating) }
}

// MARK: - Preview
#Preview {
    CelestialCanva()
        .environment(EAppState())
}



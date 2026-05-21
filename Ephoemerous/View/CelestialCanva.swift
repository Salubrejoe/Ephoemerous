import SwiftUI
import UIKit
import CoreLocation


struct CelestialCanva: View {

    @Environment(EAppState.self) var state

    // Every touch interaction lives in the coordinator (own file / class).
    @State private var gestures = CelestialGestureCoordinator()

    // MARK: - Layers
    //
    // Rebuilt each render so the six NS/UL-parametrised layers pick up
    // the current `state.layerMode` (= .northSouth in clock, .userLocation
    // in travel). The mode flip happens at the end (forward) or start
    // (reverse) of the origin slerp — at lat 90° the two projections are
    // identical, so the swap is invisible.
    //
    // EarthGridLayer + HorizonLayer are always UL: they're the visible
    // animation during the slerp (the horizon morphs as the observer
    // travels to / from the pole).
    //
    // Chrome layers (WatchBackgroundLayer + ClipAndHoursLayer) self-gate
    // on `appMode == .clock` so they disappear / reappear in lockstep
    // with the flip.
    private var layers: [any EGridLayer] {
        let m = state.layerMode
        return [
            WatchBackgroundLayer(),
            EarthGridLayer(mode: .userLocation),
            HorizonLayer(),
            CardinalLabelsLayer(),
            ConstellationLinesLayer(mode: m),
            StarsLayer(mode: m),
            ConstellationNamesLayer(mode: m),
            EclipticLayer(mode: m),
            SunLayer(mode: m),
            EMoonLayer(mode: m),
            EPlanetsLayer(mode: m),
            SelectedStarsLayer(mode: m),
            ClipAndHoursLayer(),
            WatchRimLayer(),
        ]
    }

    // MARK: - Body

    var body: some View {
        // One timeline: 60 fps during gestures/transitions, 10 fps at rest.
        // `schedule` is recomputed whenever isAnimating flips, so TimelineView
        // reschedules on the next render — no destructive .id() teardown.
        TimelineView(schedule) { timeline in
            ZStack {
                if state.appMode == .travel {
                    Color.systemBackground
                }

                Canvas { ctx, size in
                    state.advanceCanvasClock(
                        to:         timeline.date.timeIntervalSinceReferenceDate,
                        canvasSize: size
                    )
                    var dc = EGraphicContext(ctx: ctx, size: size, state: state)
                    for layer in layers { layer.draw(in: &dc) }
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
        state._originTransition   != nil ||
        state._nsOriginTransition != nil ||
        state._inertiaTransition != nil ||
        state._chromeTransition  != nil
    }
    private var schedule: ECanvasSchedule { ECanvasSchedule(isAnimating: isAnimating) }
}

// MARK: - Preview
#Preview {
    CelestialCanva()
        .environment(EAppState())
}

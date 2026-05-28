import SwiftUI
import UIKit
import CoreLocation
import LoreKit


struct CelestialCanva: View {

    @Environment(EAppState.self) var state

    // Every touch interaction lives in the coordinator (own file / class).
    @State private var gestures = CelestialGestureCoordinator()

    // MARK: - Layers
    //
    // One projection for everything — observer-centred stereographic
    // (see EProjection.project). Clock mode = "observer pinned at lat
    // 90°"; chrome layers (WatchBackgroundLayer + ClipAndHoursLayer)
    // self-gate on `appMode == .clock` so they appear / disappear with
    // the mode flip.
    private var layers: [any EGridLayer] {
        [
//            WatchBackgroundLayer(),
            EarthGridLayer(),
            ConstellationLinesLayer(),
            StarsLayer(),
            ConstellationNamesLayer(),
            // Proper-named stars: hidden below `namedStarDotIn`, then
            // dot → badge → text-tier reveal as the user zooms further
            // in (handled by drawPOILabel + `.namedStar` thresholds).
            // Sits between constellation names and the horizon wash so
            // it dims when below horizon, same as constellation labels.
            NamedStarsLayer(),
            // HorizonLayer now sits on top of grid + lines + stars + zodiac
            // glyphs, so its translucent `horizonFillColor` wash and the
            // squircle-bumped twilight rings *dim* the below-horizon region
            // instead of just tinting the canvas under it. Anything that
            // should always pop (selected stars, ecliptic, badges, user
            // puck) is drawn after.
            CardinalLabelsLayer(),
            FavouritesLayer(),
            EclipticLayer(),
            EPlanetsLayer(),
            SunLayer(),
            EMoonLayer(),
            HorizonLayer(),
            UserLocationLayer(),   // "you are here" puck — drawn last so it sits on top
//            ClipAndHoursLayer(),
//            WatchRimLayer(),
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
                    // Resolve every per-frame observable value exactly
                    // once here. The draw loops below project 10k+
                    // points; reading these off `state` per point would
                    // route every read through Observation's
                    // access(keyPath:) and melt the CPU.
                    var dc = EGraphicContext(
                        ctx:                     ctx,
                        size:                    size,
                        state:                   state,
                        renderedScale:           state.renderedScale,
                        renderedOffset:          state.renderedOffset,
                        renderedObservationDate: state.renderedObservationDate,
                        localSiderealOffset:     state.localSiderealOffset,
                        animationTime:           state.animationTime,
                        viewpoint:               state.viewpoint
                    )
                    for layer in layers { layer.draw(in: &dc) }
                }

                // Topmost, sharp & interactive: owns every canvas touch.
                // The flexible frame keeps this coordinate space immune to
                // any sibling's intrinsic size.
                CelestialGestureView(gestures: gestures, state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fontDesign(.rounded)
        .ignoresSafeArea()
        .clipped()
    }
}

// MARK: - Schedule

// Two states:
//   • Animating (gesture or transition in flight) → 120 fps so the
//     animation interpolates smoothly.
//   • Idle → emit one tick at `start` then `.distantFuture`, i.e.
//     stop firing. There are no continuous ambient animations on the
//     canvas — favourites are a static heart, the sun's breathing
//     crown is gone, stars don't twinkle. All animation happens via
//     discrete `_*Transition` flags. When all of them are nil and no
//     gesture is active, the sky is literally static and the
//     timeline ticking does nothing but burn CPU on a redundant
//     redraw of ~10k stars + constellation lines + 88 labels every
//     100 ms.
//
// Canvas observes the @Observable state read from inside its
// renderer closure (see the comment in `Canvas { … }` above), so
// observable changes (user pans, picks a new date / location, etc.)
// still redraw the sky without the timeline firing. The moment a
// gesture starts or a transition is created, `isAnimating` flips
// true via observation → view body re-evaluates → a fresh
// `ECanvasSchedule(isAnimating: true)` is handed to TimelineView,
// which resumes ticking at 120 Hz.
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
            let current = next_date
            if isAnimating {
                next_date = current.addingTimeInterval(1.0 / 120.0)
                return current
            }
            // Idle: emit one tick at start so the canvas paints once,
            // then stay parked at `.distantFuture` forever. TimelineView
            // schedules a fire for that date and effectively stops
            // doing work. When `isAnimating` flips back to true via
            // observation, the view body re-evaluates and TimelineView
            // gets a new `ECanvasSchedule(isAnimating: true)` —
            // discarding this iterator and starting the 120 Hz loop.
            if current == .distantFuture {
                return .distantFuture
            }
            next_date = .distantFuture
            return current
        }
    }
}

extension CelestialCanva {
    private var isAnimating: Bool {
        gestures.isInteracting         ||
        state._activeTransition != nil ||
        state._dateTransition   != nil ||
        state._originTransition != nil ||
        state._inertiaTransition != nil ||
        state._chromeTransition != nil
    }
    private var schedule: ECanvasSchedule { ECanvasSchedule(isAnimating: isAnimating) }
}

// MARK: - Preview
#Preview {
    CelestialCanva()
        .environment(EAppState())
}

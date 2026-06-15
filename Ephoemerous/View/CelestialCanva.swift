import SwiftUI
import UIKit
import CoreLocation
import LoreKit


struct CelestialCanva: View {

    @Environment(EAppState.self) var state
    // Whole environment, captured so the Canvas closure can resolve
    // asset-catalog colours to concrete RGBA once per frame (see
    // `EGraphicContext.resolve`) instead of doing main-thread asset I/O
    // on every draw.
    @Environment(\.self) private var environment

    // Every touch interaction lives in the coordinator (own file / class).
    @State private var gestures = CelestialGestureCoordinator()

    // MARK: - Layers
    //
    // One projection for everything — observer-centred stereographic
    // (see `EProjection.project`). Draw order is bottom → top: grid +
    // constellation lines first, then the star catalog, then labels,
    // then the horizon wash that dims the below-horizon region, then
    // anything that should always pop (favourites, ecliptic, badges,
    // user puck) on top.
    // `static let`, NOT a computed property: this is read inside the Canvas
    // closure, so a computed array would re-build all the layer structs —
    // including HorizonLabelsLayer's localized-string table — once per
    // frame, 120×/s during gestures. The layers are stateless values; build
    // them once.
    private static let layers: [any EGridLayer] =
        [
            UserLocationLayer(),   // "you are here" puck
            EarthGridLayer(),
            // Aim sky-wash: blue glow where the phone points, clipped to
            // the horizon dome. Drawn early so it tints the background
            // behind every star rather than fogging the foreground.
//            SkyAimWashLayer(),
            ConstellationLinesLayer(),
            StarsLayer(),
            // Proper-named stars: hidden below `namedStarDotIn`, then
            // dot → badge → text-tier reveal as the user zooms further
            // in (handled by `drawPOILabel` + `.namedStar` thresholds).
            ConstellationNamesLayer(),
            NamedStarsLayer(),
            FavouritesLayer(),
            EclipticLayer(),
            EPlanetsLayer(),
            SunLayer(),
            MoonLayer(),
                        HorizonLabelsLayer(),
                        MeridianLabelsLayer(),
//            HorizonLayer(),
            // EASTERN / WESTERN HORIZON cartographic labels curving
            // along the projected alt = 0 rim. Sits after HorizonLayer
            // so the text reads against the tinted below-horizon wash,
            // before the user puck so the puck draws on top.
            // VERNAL / SUMMER / AUTUMNAL / WINTER labels curving along the
            // four principal meridians (the colures), same cartographic
            // treatment as the horizon labels — riding constant-RA grid
            // lines instead of the alt = 0 rim.
        ]

    // MARK: - Body

    var body: some View {
        // One timeline: 120 fps during gestures/transitions, parked at
        // rest. `schedule` is recomputed whenever isAnimating flips, so
        // TimelineView reschedules on the next render — no destructive
        // .id() teardown.
        TimelineView(schedule) { timeline in
            ZStack {
                Canvas { ctx, size in
                    let frameStart = CACurrentMediaTime()   // EFrameMeter probe
                    state.advanceCanvasClock(
                        to:         timeline.date.timeIntervalSinceReferenceDate,
                        canvasSize: size
                    )
                    // Drop the glyph-heavy labels while the sky is being
                    // moved (live gesture or fling glide) — Maps-style.
                    // Reading `isInteracting` / `_inertiaTransition` here
                    // registers the dependency, so the canvas repaints
                    // (labels back) the moment motion ends.
                    let suppressLabels = gestures.isInteracting
                        || state._inertiaTransition != nil
                    // Resolve every per-frame observable value exactly
                    // once here. The draw loops below project 10k+
                    // points; reading these off `state` per point would
                    // route every read through Observation's
                    // access(keyPath:) and melt the CPU.
                    var dc = EGraphicContext(
                        ctx:                     ctx,
                        size:                    size,
                        state:                   state,
                        environment:             environment,
                        renderedScale:           state.renderedScale,
                        renderedOffset:          state.renderedOffset,
                        renderedObservationDate: state.renderedObservationDate,
                        localSiderealOffset:     state.localSiderealOffset,
                        animationTime:           state.animationTime,
                        viewpoint:               state.viewpoint,
                        canvasRotation:          state.renderedRotation,
                        selectedObjectID:        state.detailDestination?.id,
                        selectionStart:          state._selectionStart,
                        deselectingID:           state._deselectingID,
                        deselectStart:           state._deselectStart,
                        suppressLabels:          suppressLabels
                    )
                    for layer in Self.layers { layer.draw(in: &dc) }
                    EFrameMeter.shared.record(frameStart: frameStart)
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
                next_date = current.addingTimeInterval(1.0 / 60)
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
        state.compassMode              ||   // heading-up: tick smoothly so the
                                            // sky glides with the phone instead
                                            // of repainting only on quantized
                                            // 30 Hz aim changes (the stutter).
        state._activeTransition  != nil ||
        state._dateTransition    != nil ||
        state._originTransition  != nil ||
        state._inertiaTransition != nil ||
        state._rotationTransition != nil ||
        state._promotionActive
    }
    private var schedule: ECanvasSchedule { ECanvasSchedule(isAnimating: isAnimating) }
}

// MARK: - Preview
#Preview {
    CelestialCanva()
        .environment(EAppState())
}

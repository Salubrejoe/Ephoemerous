import SwiftUI
import UIKit
import CoreLocation


struct CelestialCanva: View {
    
    @Environment(EAppState.self) var state
    
    
    // MARK: - Layers
    // Layers drawn inside the clip circle, back → front
    private let skyLayers: [any EGridLayer] = [
        WatchBackgroundLayer(),
        EStarsLayer(mode: .northSouth),
        HorizonLayer(),
//        EMilkyWayLayer(mode: .northSouth),
        
    ]
    private let clockLayers: [any EGridLayer] = [
//        EarthGrid(mode: .northSouth),
        EarthGridLayer(mode: .userLocation),
        EclipticLayer(mode: .northSouth),
        EMoonLayer(mode: .northSouth),
        ESunLayer(mode: .northSouth),
        ESelectedStarsLayer(mode: .northSouth),
        CrownHours(),
    ]
    
    private let travelLayers: [any EGridLayer] = [
//        ESkyBackgroundLayer(),
        EarthGridLayer(mode: .userLocation),
        HorizonLayer(),
//        EMilkyWayLayer(mode: .userLocation),
//        EEclipticLayer(mode: .userLocation),
//        EStarsLayer(mode: .userLocation),
//        ESunLayer(mode: .userLocation),
//        EMoonLayer(mode: .userLocation),
//        EPlanetsLayer(mode: .userLocation),
//        ESelectedStarsLayer(mode: .userLocation),
    ]
    
    // Every touch interaction lives in the coordinator (own file / class).
    @State private var gestures = CelestialGestureCoordinator()

    // MARK: - Body

    var body: some View {
        // One timeline: 60 fps during gestures/transitions, 10 fps at rest.
        // `schedule` is recomputed whenever isAnimating flips, so TimelineView
        // reschedules on the next render — no destructive .id() teardown.
        TimelineView(schedule) { timeline in
            // Defocus swap envelope: 0 at rest → 1 at the mid-transition
            // (where appMode flips) → 0. A per-star morph is geometrically
            // impossible and layers self-gate on appMode, so the modes are
            // swapped atomically under peak blur instead of cross-faded.
            let env = state.renderedTransitionEnvelope

            ZStack {
                ZStack {
                    if state.appMode == .travel {
                        Color.systemBackground
                    }

                    Canvas { ctx, size in
                        state.advanceCanvasClock(
                            to:         timeline.date.timeIntervalSinceReferenceDate,
                            canvasSize: size
                        )
                        guard state.appMode == .clock else { return }
                        var innerDC = innerDC(ctx: ctx, size: size)
                        for layer in skyLayers { layer.draw(in: &innerDC) }
                    }

                    Canvas { ctx, size in
                        var dc = EGraphicContext(ctx: ctx, size: size, state: state)
                        let layers = state.appMode == .clock ? clockLayers : travelLayers
                        for layer in layers { layer.draw(in: &dc) }
                    }

//                    if state.appMode == .clock {
////                        // Layout sink: the crown's rings are framed to the
////                        // zoom (radius ∝ renderedScale); without this the
////                        // ZStack grows with scale and drags the gesture
////                        // view's coordinate space under the finger.
//                        WatchMaskView()
//                            .frame(maxWidth: .infinity, maxHeight: .infinity)
//                            .clipped()
//                    }
                }
                // Scale up as it defocuses out / down as it sharpens in —
                // the clipped disc appears to open past the screen (clock
                // leaving) and close back into place (clock returning).
//                .scaleEffect(1 + 0.6 * env)
                .blur(radius: 20 * env)
                .opacity(1 - 0.9 * env)

                // Topmost, sharp & interactive (outside the defocus): owns
                // every canvas touch. The flexible frame keeps this
                // coordinate space immune to any sibling's intrinsic size.
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

// MARK: - Helpers
extension CelestialCanva {
    private func innerDC(ctx: GraphicsContext, size: CGSize) -> EGraphicContext {
        // Clip circle matching the crown's inner edge (dec = -30°)
        let cx = size.width  / 2 + state.renderedOffset.y
        let cy = size.height / 2 + state.renderedOffset.x
        let r  = state.renderedScale * EArtist.shared.clipRadius
               + EArtist.shared.clipBleed
        let clipPath = Path(
            ellipseIn:
                CGRect(
                    x: cx - r,
                    y: cy - r,
                    width: 2 * r,
                    height: 2 * r
                )
        )
        
        // Inner layers — drawn inside the clipped projection disk
        var clippedCtx = ctx
        clippedCtx.clip(to: clipPath)
        return EGraphicContext(ctx: clippedCtx, size: size, state: state)
    }
}




// MARK: - Preview
#Preview {
    CelestialCanva()
        .environment(EAppState())
}



import SwiftUI
import UIKit
import CoreLocation


struct CelestialCanva: View {
    
    @Environment(EAppState.self) var state
    
    
    // MARK: - Layers
    // Layers drawn inside the clip circle, back → front
    private let skyLayers: [any EGridLayer] = [
        ESkyBackgroundLayer(),
        EMilkyWayLayer(mode: .northSouth),
        EEquatorTropicsLayer(mode: .northSouth),
        EMeridiansLayer(mode: .userLocation),
        EEclipticLayer(mode: .northSouth),
        EStarsLayer(mode: .northSouth),
    ]
    private let clockLayers: [any EGridLayer] = [
        EMoonLayer(mode: .northSouth),
        ESunLayer(mode: .northSouth),
        ESelectedStarsLayer(mode: .northSouth),
    ]
    
    private let travelLayers: [any EGridLayer] = [
//        ESkyBackgroundLayer(),
        EMilkyWayLayer(mode: .userLocation),
        EEquatorTropicsLayer(mode: .userLocation),
        EEclipticLayer(mode: .userLocation),
        EMeridiansLayer(mode: .userLocation),
        EStarsLayer(mode: .userLocation),
        ESunLayer(mode: .userLocation),
        EMoonLayer(mode: .userLocation),
        EPlanetsLayer(mode: .userLocation),
        ESelectedStarsLayer(mode: .userLocation),
    ]
    
    // Every touch interaction lives in the coordinator (own file / class).
    @State private var gestures = CelestialGestureCoordinator()

    // MARK: - Body

    var body: some View {
        // One timeline: 60 fps during gestures/transitions, 10 fps at rest.
        // `schedule` is recomputed whenever isAnimating flips, so TimelineView
        // reschedules on the next render — no destructive .id() teardown.
        TimelineView(schedule) { timeline in
            // 0 = clock, 1 = travel. Drives a cross-fade between the two
            // compositions (a per-star morph is geometrically impossible —
            // the two view centres are ~141° apart through a projection
            // blind past 90°; see spikes/projection_frame_spike.swift).
            let blend = state.renderedProjectionBlend

            ZStack {
                // Clock composition — fades out as blend → 1.
                ZStack {
                    Canvas { ctx, size in
                        // Single per-frame driver: advance the clock even
                        // when this group is invisible (blend == 1) so
                        // animationTime / inertia / the blend keep ticking.
                        state.advanceCanvasClock(
                            to:         timeline.date.timeIntervalSinceReferenceDate,
                            canvasSize: size
                        )
                        guard blend < 0.999 else { return }
                        var innerDC = innerDC(ctx: ctx, size: size)
                        for layer in skyLayers { layer.draw(in: &innerDC) }
                    }
                    Canvas { ctx, size in
                        guard blend < 0.999 else { return }
                        var dc = EGraphicContext(ctx: ctx, size: size, state: state)
                        for layer in clockLayers { layer.draw(in: &dc) }
                    }
                    if blend < 0.999 {
                        // Layout sink: the crown's rings are framed to the
                        // zoom (radius ∝ renderedScale); without this the
                        // ZStack grows with scale and drags the gesture
                        // view's coordinate space under the finger.
                        WatchMaskView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    }
                }
                .opacity(1 - blend)

                // Travel composition — fades in as blend → 1.
                ZStack {
                    Rectangle()
                        .fill(LinearGradient(colors: [.darkIndigo,
                                                      .darkIndigo.opacity(0.5)],
                                             startPoint: .top, endPoint: .bottom))
                    Canvas { ctx, size in
                        guard blend > 0.001 else { return }
                        var dc = EGraphicContext(ctx: ctx, size: size, state: state)
                        for layer in travelLayers { layer.draw(in: &dc) }
                    }
                }
                .opacity(blend)

                // Topmost: owns every canvas touch. The flexible frame keeps
                // this coordinate space immune to any sibling's intrinsic
                // size (the layout-routed gesture feedback fix).
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



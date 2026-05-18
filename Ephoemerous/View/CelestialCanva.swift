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
    
    private var outerLayers: [any EGridLayer] { state.appMode == .clock ? clockLayers : travelLayers }
    
    // Every touch interaction lives in the coordinator (own file / class).
    @State private var gestures = CelestialGestureCoordinator()

    // MARK: - Body

    var body: some View {
        // One timeline: 60 fps during gestures/transitions, 10 fps at rest.
        // `schedule` is recomputed whenever isAnimating flips, so TimelineView
        // reschedules on the next render — no destructive .id() teardown.
        TimelineView(schedule) { timeline in
            ZStack {
                Canvas { ctx, size in
                    state.advanceCanvasClock(
                        to:         timeline.date.timeIntervalSinceReferenceDate,
                        canvasSize: size
                    )
                    var innerDC = innerDC(ctx: ctx, size: size)
                    if state.appMode == .clock {
                        for layer in skyLayers { layer.draw(in: &innerDC) }
                    }
                }
                
                    
                
                Canvas { ctx, size in
                    var outerDC = EGraphicContext(ctx: ctx, size: size, state: state)
                    for layer in outerLayers { layer.draw(in: &outerDC) }
                }
                if state.appMode == .clock {
                    WatchMaskView()
                        
                }
            }
        }
        .ignoresSafeArea()
        .clipped()
        // Same frame the inner Canvas reports as `size`, so a tap read in
        // this space lines up exactly with toScreen — no nav-bar/safe-area
        // inset bias on the double-tap zoom.
        .coordinateSpace(.named("celestialCanvas"))
        .animation(.default, value: state.appMode)
        .gesture(gestures.primaryGesture(state: state))
        .simultaneousGesture(gestures.magnificationGesture(state: state))
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
        state._originTransition  != nil ||
        state._inertiaTransition != nil   // keep 60 fps while the fling glides
    }
    private var schedule: ECanvasSchedule { ECanvasSchedule(isAnimating: isAnimating) }
}

// MARK: - Helpers
extension CelestialCanva {
    private func innerDC(ctx: GraphicsContext, size: CGSize) -> EGraphicContext {
        // Clip circle matching the crown's inner edge (dec = -30°)
        let cx = size.width  / 2 + state.renderedOffset.y
        let cy = size.height / 2 + state.renderedOffset.x
        let r  = 2 * sqrt(3) * state.renderedScale
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



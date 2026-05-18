import SwiftUI
import UIKit
import CoreLocation


struct CelestialCanva: View {
    
    @Environment(EAppState.self) var state
    
    
    // MARK: - Layers
    // Layers drawn inside the clip circle, back → front
    private let skyLayers: [any EGridLayer] = [
        EEquatorTropicsLayer(mode: .northSouth),
//        EMeridiansLayer(mode: .northSouth),
        EMeridiansLayer(mode: .userLocation),
        EEclipticLayer(mode: .northSouth),
//        EPlanetsLayer(mode: .northSouth),
        EStarsLayer(mode: .northSouth),
//        EULHorizonLayer()
    ]
    private let clockLayers: [any EGridLayer] = [
//        EStarsLayer(mode: .northSouth),
//        EMeridiansLayer(mode: .userLocation),
        EMoonLayer(mode: .northSouth),
        ESunLayer(mode: .northSouth),
        ESelectedStarsLayer(mode: .northSouth),
//        ENSWatchCrownLayer(),
    ]
    
    private let travelLayers: [any EGridLayer] = [
        EEquatorTropicsLayer(mode: .userLocation),
        EEclipticLayer(mode: .userLocation),
        EMeridiansLayer(mode: .userLocation),
        EStarsLayer(mode: .userLocation),
        ESunLayer(mode: .userLocation),
        EMoonLayer(mode: .userLocation),
        EPlanetsLayer(mode: .userLocation),
        ESelectedStarsLayer(mode: .userLocation),
//        ENSWatchCrownLayer(),
    ]
    
    private var outerLayers: [any EGridLayer] { state.appMode == .clock ? clockLayers : travelLayers }
    
    // Every touch interaction lives in the coordinator (own file / class).
    @State private var gestures = CelestialGestureCoordinator()

    // Schedule invalidation -- bump to wake the TimelineView immediately
    @State private var scheduleID: Int = 0
    
    
    
    // MARK: - Body
    
    var body: some View {
        // Single timeline: 60fps during gestures/transitions, 1/min at rest.
        // animationTime is updated here -- transitions only interpolate when this fires fast.
        TimelineView(schedule) { timeline in
            ZStack {
                Canvas { ctx, size in
                    state.animationTime = timeline.date.timeIntervalSinceReferenceDate
                    if var t = state._inertiaTransition {
                        let (dx, dy, finished) = t.advance(to: state.animationTime)
                        let advanced = t
                        DispatchQueue.main.async {
                            state.offset.x += dx
                            state.offset.y += dy
                            state._inertiaTransition = finished ? nil : advanced
                        }
                    }
                    
                    if let t = state._originTransition {
                        let (lat, lon) = t.interpolated(at: state.animationTime)
                        let finished = t.isFinished(at: state.animationTime)
                        DispatchQueue.main.async {
                            state.setOrigin(lat: .radians(lat), lon: .radians(lon))
                            if finished { state._originTransition = nil }
                        }
                    }; if state.canvasSize != size { DispatchQueue.main.async { state.canvasSize = size } }
                    
                    var innerDC = innerDC(ctx: ctx, size: size)
                    for layer in skyLayers { layer.draw(in: &innerDC) }
                    
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
        .animation(.default, value: state.appMode)
        .id(scheduleID)
        .gesture(gestures.viewportDragGesture(state: state))
        .simultaneousGesture(gestures.magnificationGesture(state: state))
        .onChange(of: state._dateTransition != nil || state._activeTransition != nil || state._originTransition != nil || state._inertiaTransition != nil) {
            scheduleID &+= 1  // wake TimelineView immediately when transition starts
        }
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



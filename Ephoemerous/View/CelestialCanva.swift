import SwiftUI
import CoreLocation


struct CelestialCanva: View {
    
    @Environment(EAppState.self) var state
    
    
    // MARK: - Layers
    // Layers drawn inside the clip circle, back → front
    private let innerLayers: [any EGridLayer] = [
        //        ENSEquatorTropicsLayer(),
        //        ENSEclipticLayer(),
        EULHorizonLayer(),
        ENSWatchCrownLayer()
    ]
    
    // Layers drawn outside the clip circle (crown ring)
    private let outerLayers: [any EGridLayer] = [
        ENSStarsLayer(),
        ENSSunLayer(),
        ENSMoonLayer(),
        ENSPlanetsLayer(),
        ENSWatchCrownLayer(),
        ENSSelectedStarsLayer(),
    ]
    
    // Drag state
    @State private var isDragging    = false
    @State private var dragStartLat: Double = 0
    @State private var dragStartLon: Double = 0
    
    // Schedule invalidation -- bump to wake the TimelineView immediately
    @State private var scheduleID: Int = 0

    // Pinch state
    @State private var isPinching       = false
    @State private var pinchStartScale:  Double   = 50
    @State private var pinchStartOffset: CGPoint  = .zero
    @State private var pinchSkyAnchor:   CGPoint  = .zero

    
    
    // MARK: - Body
    
    var body: some View {
        // Single timeline: 60fps during gestures/transitions, 1/min at rest.
        // animationTime is updated here -- transitions only interpolate when this fires fast.
        TimelineView(schedule) { timeline in
            ZStack {
                Canvas { ctx, size in
                    state.animationTime = timeline.date.timeIntervalSinceReferenceDate; if state.canvasSize != size { DispatchQueue.main.async { state.canvasSize = size } }
                    
                    var innerDC = innerDC(ctx: ctx, size: size)
                    for layer in innerLayers { layer.draw(in: &innerDC) }
                    
                }
                Canvas { ctx, size in
                    var outerDC = EGraphicContext(ctx: ctx, size: size, state: state)
                    for layer in outerLayers { layer.draw(in: &outerDC) }
                }
            }
        }
                        .id(scheduleID)
        .gesture(dragGesture)
        .simultaneousGesture(pinchGesture)
        .onChange(of: state._dateTransition != nil || state._activeTransition != nil) {
            scheduleID &+= 1  // wake TimelineView immediately when transition starts
        }
    }
}

// MARK: - Gestures
extension CelestialCanva {
    
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                if state._activeTransition != nil {
                    state.offset = state.renderedOffset
                    state._activeTransition = nil
                }
                if !isDragging {
                    isDragging   = true
                    dragStartLat = state.offset.x
                    dragStartLon = state.offset.y
                }
                state.offset.x = dragStartLat + v.translation.height
                state.offset.y = dragStartLon + v.translation.width
            }
            .onEnded { _ in isDragging = false }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let size = state.canvasSize
                if !isPinching {
                    isPinching = true
                    // Snap from animated values so there is no jump
                    if state._activeTransition != nil {
                        state.scale  = state.renderedScale
                        state.offset = state.renderedOffset
                        state._activeTransition = nil
                    }
                    pinchStartScale  = state.scale
                    pinchStartOffset = state.offset
                    // Finger midpoint in screen space
                    let mx = v.startAnchor.x * size.width
                    let my = v.startAnchor.y * size.height
                    // Invert toScreen to get the sky point under the fingers
                    pinchSkyAnchor = CGPoint(
                        x: (mx - size.width  / 2 - state.offset.y) / state.scale,
                        y: (size.height / 2 + state.offset.x - my) / state.scale
                    )
                }
                let newScale = (pinchStartScale * Double(v.magnification)).clamped(to: 20 ... 1_000)
                // Recompute offset so the sky anchor stays fixed under the finger midpoint
                let mx = v.startAnchor.x * size.width
                let my = v.startAnchor.y * size.height
                state.scale    = newScale
                state.offset.y = mx - size.width  / 2 - pinchSkyAnchor.x * newScale
                state.offset.x = my - size.height / 2 + pinchSkyAnchor.y * newScale
            }
            .onEnded { _ in isPinching = false }
    }
}

// MARK: - Schedule

// Switches between 60fps (gestures/transitions) and 1-per-minute (idle).
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
                : current.addingTimeInterval(60)
            return current
        }
    }
}

extension CelestialCanva {
    private var isAnimating: Bool {
        isPinching               ||
        state._activeTransition != nil ||
        state._dateTransition   != nil
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


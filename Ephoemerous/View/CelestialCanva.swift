import SwiftUI
import CoreLocation


struct CelestialCanva: View {
    
    @Environment(EAppState.self) var state
    
    
    // MARK: - Layers
    // Layers drawn inside the clip circle, back → front
    private let innerLayers: [any EGridLayer] = [
        //        ENSEquatorTropicsLayer(),
        //        ENSEclipticLayer(),
        ENSSunLayer(),
        ENSMoonLayer(),
        ENSPlanetsLayer(),
        EULHorizonLayer(),
        ENSSelectedStarsLayer(),
        ENSWatchCrownLayer()
    ]
    
    // Layers drawn outside the clip circle (crown ring)
    private let outerLayers: [any EGridLayer] = [
        ENSWatchCrownLayer(),
        ENSStarsLayer(),
    ]
    
    // Drag state
    @State private var isDragging    = false
    @State private var dragStartLat: Double = 0
    @State private var dragStartLon: Double = 0
    
    // Pinch state
    @State private var isPinching       = false
    @State private var pinchStartScale: Double = 50
    
    
    // MARK: - Body
    
    var body: some View {
        
            TimelineView(.animation) { timeline in
                ZStack {
                Canvas { ctx, size in
            /// Avoid mutating state directly for type inference issues; update via separate modifier if needed
                    state.animationTime = timeline.date.timeIntervalSinceReferenceDate
                    
                    var innerDC = innerDC(ctx: ctx, size: size)
                    for layer in innerLayers { layer.draw(in: &innerDC) }
                    
                }
                Canvas { ctx, size in
                    var outerDC = EGraphicContext(ctx: ctx, size: size, state: state)
                    for layer in outerLayers { layer.draw(in: &outerDC) }
                }
            }
        }
        .gesture(dragGesture)
        .simultaneousGesture(pinchGesture)
    }
}

// MARK: - Gestures
extension CelestialCanva {
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                if !isDragging {
                    isDragging   = true
                    dragStartLat = state.offset.x
                    dragStartLon = state.offset.y
                }
                let newX = (dragStartLat + v.translation.height)
                //                    .clamped(
                ////                        to: -1 * .piHalf ... .piHalf
                ////                        to: 0.0 ... Double.pi
                //                        to: -0.499 * .pi ... .pi * 0.499
                //                    )
                let newY = dragStartLon + v.translation.width
                //                let newLon = dragStartLon
                //                state.setOrigin(lat: .radians(newLat), lon: .radians(newLon))
                //                withAnimation {
                state.offset.x = newX
                state.offset.y = newY
                //                }
                
            }
            .onEnded { _ in isDragging = false }
    }
    
    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                if !isPinching {
                    isPinching      = true
                    pinchStartScale = state.scale
                }
                state.scale = (pinchStartScale * Double(v.magnification))
                    .clamped(to: 20 ... 1_000)
            }
            .onEnded { _ in isPinching = false }
    }
}


// MARK: - Helpers
extension CelestialCanva {
    private func innerDC(ctx: GraphicsContext, size: CGSize) -> EGraphicContext {
        // Clip circle matching the crown's inner edge (dec = -30°)
        let cx = size.width  / 2 + state.offset.y
        let cy = size.height / 2 + state.offset.x
        let r  = 2 * sqrt(3) * state.scale
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



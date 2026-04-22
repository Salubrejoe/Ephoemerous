import SwiftUI
import CoreLocation

// MARK: - Layer protocol

protocol EGridLayer {
    typealias Vector3D = SIMD3<Double>
    func draw(in dc: inout EGraphicContext)
}

// MARK: - EPHSkyCanvasView

struct ESkyCanvaView: View {

    @Environment(EAppState.self) var state

    // Drag state
    @State private var isDragging    = false
    @State private var dragStartLat: Double = 0
    @State private var dragStartLon: Double = 0

    // Pinch state
    @State private var isPinching       = false
    @State private var pinchStartScale: Double = 50

    // Layers drawn inside the clip circle, back → front
    private let innerLayers: [any EGridLayer] = [
        ENSGlobeLayer(),
        ENSEclipticLayer(),
        ENSSunLayer(),
        ESelectedStarLayer(),
        EMoonLayer(),
//        ENSMoonLayer(),
        ENSStarsLayer(),
        EPlanetsLayer(),
        EUserHorizonLayer(),
    ]

    // Layers drawn outside the clip circle (crown ring)
    private let outerLayers: [any EGridLayer] = [
//        ENSGlobeLayer(),
//        ENSEclipticLayer(),
//        ENSSunLayer(),
        ENSStarsLayer(),
        EMoonLayer(),
//        EPlanetsLayer(),
//        EUserGlobeLayer(),
//        ENSWatchCrownLayer(),
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            
            Color(uiColor: .secondarySystemBackground)
                .ignoresSafeArea()
//            LinearGradient(colors: [.blue.opacity(0.5), Color(uiColor: .secondarySystemBackground)], startPoint: .top, endPoint: .bottom)
//                .ignoresSafeArea()
            
            Group {
                TimelineView(.animation) { timeline in
                    Canvas { ctx, size in
                        // Avoid mutating state directly for type inference issues; update via separate modifier if needed
                        // state.animationTime = timeline.date.timeIntervalSinceReferenceDate
                        
                        // Clip circle matching the crown's inner edge (dec = -30°)
                        let cx = size.width  / 2 + state.offset.y
                        let cy = size.height / 2 + state.offset.x
                        let r  = ENSWatchCrownLayer.clipRadius * state.scale
                        let clipPath = Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                                              width: 2 * r, height: 2 * r))
                        
                        // Inner layers — drawn inside the clipped projection disk
                        var clippedCtx = ctx
                        clippedCtx.clip(to: clipPath)
                        var innerDC = EGraphicContext(ctx: clippedCtx, size: size, state: state)
                        for layer in innerLayers { layer.draw(in: &innerDC) }
                        
                    }
                }
                
                Canvas { ctx, size in
                    var topDC = EGraphicContext(ctx: ctx, size: size, state: state)
                    // ... draw your top layer
                    for layer in outerLayers { layer.draw(in: &topDC) }
                }
                .blur(radius: 2)
                
                Canvas { ctx, size in
                    var sunDC = EGraphicContext(ctx: ctx, size: size, state: state)
                    ENSSunLayer().draw(in: &sunDC)
                }
                .brightness(1)
                .blur(radius: 2)
            }
            .ignoresSafeArea()
            .gesture(dragGesture)
            .simultaneousGesture(pinchGesture)
            .onChange(of: Date.now) { _, _ in
                state.animationTime = Date().timeIntervalSinceReferenceDate
            }
        }
        
    }

    // MARK: - Gestures
//
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                if !isDragging {
                    isDragging   = true
                    dragStartLat = state.origin.latitude.radians
                    dragStartLon = state.origin.longitude.radians
                }
                let newLat = (dragStartLat - v.translation.height/3 / state.scale)
                    .clamped(
//                        to: -1 * .piHalf ... .piHalf
//                        to: 0.0 ... Double.pi
                        to: -0.499 * .pi ... .pi * 0.499
                    )
//                let newLon = dragStartLon + v.translation.width/3 / state.scale
                let newLon = dragStartLon
                state.setOrigin(lat: .radians(newLat), lon: .radians(newLon))
                
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


// MARK: - Numeric helper

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}


// MARK: - Preview

#Preview {
    ESkyCanvaView()
        .environment(EAppState())
}


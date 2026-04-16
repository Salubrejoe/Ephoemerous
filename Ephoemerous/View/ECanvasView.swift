import SwiftUI

// MARK: - Layer protocol

protocol EGridLayer {
    typealias Vector3D = SIMD3<Double>
    func draw(in dc: inout EGraphicContext)
}


// MARK: - EPHSkyCanvasView

struct ECanvasView: View {

    @Environment(EAppState.self) var state

    // Drag state
    @State private var isDragging    = false
    @State private var dragStartLat: Double = 0
    @State private var dragStartLon: Double = 0

    // Pinch state
    @State private var isPinching       = false
    @State private var pinchStartScale: Double = 160

    // Draw layers, back → front
    private let layers: [any EGridLayer] = [
        EMeridiansLayer(),
        EParallelsLayer(),
        EStarsLayer(),
        EEclipticLayer(),
        ESiriusLayer(),
        ESunLayer(),
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            
            Color(uiColor: .tertiarySystemBackground)
                .ignoresSafeArea()
            
            Canvas { ctx, size in
                var dc = EGraphicContext(ctx: ctx, size: size, state: state)
                for layer in layers { layer.draw(in: &dc) }
            }
            .ignoresSafeArea()
            .gesture(dragGesture)
            .simultaneousGesture(pinchGesture)
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                if !isDragging {
                    isDragging   = true
                    dragStartLat = state.originLat
                    dragStartLon = state.originLon
                }
                let newLat = (dragStartLat - v.translation.height / state.scale)
                    .clamped(to: -.pi * 0.4 ... .pi * 0.4)
                let newLon = dragStartLon + v.translation.width / state.scale
                state.setOrigin(lat: newLat, lon: newLon)
                
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
    ECanvasView()
}


import SwiftUI


struct SunMoonTrackingOverlay: View {
    @Environment(EAppState.self) var state
    
    var body: some View {
        GeometryReader { _ in
            ZStack {
                if let sunPt = state.sunScreenPosition {
                    ClearCircle(at: sunPt)
                        .onTapGesture { state.showSunInfo = true }
                }
                if let moonPt = state.moonScreenPosition {
                    ClearCircle(at: moonPt)
                        .onTapGesture { state.showMoonInfo = true }
                }
            }
        }
        .allowsHitTesting(true)
    }
    
    @ViewBuilder
    private func ClearCircle(at point: CGPoint) -> some View {
        Circle()
            .fill(Color.clear)
            .contentShape(Circle())
            .frame(width: 44, height: 44)
            .position(point)
    }
}

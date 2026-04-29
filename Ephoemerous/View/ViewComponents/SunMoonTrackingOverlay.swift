
import SwiftUI


struct SunMoonTrackingOverlay: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss
    
    @State private var showStarView : Bool = false
    @State private var selectedStar : EStar?
    
    var body: some View {
        GeometryReader { _ in
            ZStack {
                if let sunPt = state.sunScreenPosition {
                    ClearCircle(at: sunPt)
                        .onTapGesture {
                            state.showStarList = false
                            state.applySunTracking()
                            state.showSunInfo = true
                        }
                }
                if let moonPt = state.moonScreenPosition {
                    ClearCircle(at: moonPt)
                        .onTapGesture {
                            state.showStarList = false
                            state.applyMoonTracking()
                            state.showMoonInfo = true
                        }
                }
                ForEach(state.selectedStars.uniqued(by: \.name), id: \.name) { star in
                    if let pt = state.selectedStarPositions[star.name] {
                        ClearCircle(at: pt)
                            .onTapGesture {
                                state.showStarList = false
                                state.applyStarTracking(star)
                                selectedStar = star
                                showStarView = true
                                
                            }
                    }
                }
            }
            .bottomSheet(
                .allStars,
                isPresented: $showStarView,
                content: {
                    NavigationStack {
                        if let star = selectedStar {
                            EStarDetailView(star: star)
                        }
                    }
                }
            )
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


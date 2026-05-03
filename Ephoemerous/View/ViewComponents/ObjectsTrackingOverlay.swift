
import SwiftUI


struct ObjectsTrackingOverlay: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss
    
    @State private var showStarView : Bool = false
    
    
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                
                if let sunPt = state.sunScreenPosition {
                    ClearCircle(at: sunPt)
                        .onTapGesture {
                            state.showStarList = false
                            state.showMoonInfo = false
                            showStarView = false
                            state.applySunTracking()
                            state.showSunInfo = true
                        }
                }
                if let moonPt = state.moonScreenPosition {
                    ClearCircle(at: moonPt)
                        .onTapGesture {
                            state.showStarList = false
                            state.showSunInfo = false
                            showStarView = false
                            state.applyMoonTracking()
                            state.showMoonInfo = true
                        }
                }
                ForEach(state.selectedStars.uniqued(by: \.name), id: \.name) { star in
                    if let pt = state.selectedStarPositions[star.name] {
                        ClearCircle(at: pt)
                            .onTapGesture {
                                state.showStarList = false
                                state.showSunInfo = false
                                state.showMoonInfo = false
                                state.applyStarTracking(star)
                                state.currentlyDisplayedStar = star
                                showStarView = true
                            }
                    }
                }
            }
            .sheet(isPresented: $showStarView) {
                NavigationStack {
                    if let star = state.currentlyDisplayedStar {
                        EStarDetailView(star: star)
                            .onDisappear {
                                state.currentlyDisplayedStar = nil
                            }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
            }
        }
        .allowsHitTesting(true)
        .ignoresSafeArea()
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



import SwiftUI


struct ObjectsTrackingOverlay: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss
    
    @State private var showStarView : Bool = false
    
    
    
    var body: some View {
//        GeometryReader { geo in
            ZStack {
                
                // SUN
                if let sunPt = state.sunScreenPosition {
                    ClearCircle(at: sunPt)
                        .onTapGesture {
                            state.closeAllSheets()
                            state.applySunTracking()
                            state.showSunInfo = true
                        }
                }
                
                // MOON
                if let moonPt = state.moonScreenPosition {
                    ClearCircle(at: moonPt)
                        .onTapGesture {
                            state.closeAllSheets()
                            state.applyMoonTracking()
                            state.showMoonInfo = true
                        }
                }
                
                // SELECTED STARS
                ForEach(state.selectedStars.uniqued(by: \.name), id: \.name) { star in
                    if let pt = state.selectedStarPositions[star.name] {
                        ClearCircle(at: pt)
                            .onTapGesture {
                                state.closeAllSheets()
                                state.applyStarTracking(star)
                                state.currentlyDisplayedStar = star
                                showStarView = true
                            }
                    }
                }
            }
            
            .sheet(isPresented: Bindable(state).showSunInfo) {
                NavigationStack {
                    ESunDetailView()
                        .sheetFormat()
                }
            }
            
            .sheet(isPresented: Bindable(state).showMoonInfo) {
                NavigationStack {
                    EMoonDetailView()
                        .sheetFormat()
                }
            }
            
            .sheet(isPresented: $showStarView) {
                NavigationStack {
                    if let star = state.currentlyDisplayedStar {
                        EStarDetailView(star: star)
                            .sheetFormat()
                            .onDisappear {
                                state.currentlyDisplayedStar = nil
                            }
                    }
                }
            }
//        }
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


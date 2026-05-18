
import SwiftUI


struct ObjectsTrackingOverlay: View {
    @Environment(EAppState.self) var state

    var body: some View {
        ZStack {
            if let sunPoint = state.sunScreenPosition {
                ClearCircle(at: sunPoint)
                    .onTapGesture { state.presentSunInfo() }
            }

            if let moonPoint = state.moonScreenPosition {
                ClearCircle(at: moonPoint)
                    .onTapGesture { state.presentMoonInfo() }
            }

            ForEach(state.selectedStars.uniqued(by: \.name), id: \.name) { star in
                if let point = state.selectedStarPositions[star.name] {
                    ClearCircle(at: point)
                        .onTapGesture { state.presentStarInfo(star) }
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
        .sheet(isPresented: Bindable(state).showStarView) {
            NavigationStack {
                if let star = state.currentlyDisplayedStar {
                    EStarDetailView(star: star)
                        .sheetFormat()
                        .onDisappear { state.currentlyDisplayedStar = nil }
                }
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

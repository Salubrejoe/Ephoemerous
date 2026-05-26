
import SwiftUI
import LoreKit


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

            ForEach(Array(state.constellationLabelHitRects), id: \.key) { cons, rect in
                ClearCapsule(in: rect)
                    .onTapGesture { state.presentConstellationInfo(cons) }
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
        .sheet(isPresented: Bindable(state).showConstellationView) {
            NavigationStack {
                if let cons = state.currentlyDisplayedConstellation {
                    EConstellationDetailView(constellation: cons)
                        .sheetFormat()
                        .onDisappear { state.currentlyDisplayedConstellation = nil }
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

    // Constellation tap target — a capsule sized to hug the rendered
    // label (see ConstellationNamesLayer). Fill is `.clear` so it stays
    // invisible; flip to `.white` like `ClearCircle` above to eyeball
    // the hit areas while debugging.
    @ViewBuilder
    private func ClearCapsule(in rect: CGRect) -> some View {
        Capsule()
            .fill(Color.clear)
            .contentShape(Capsule())
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

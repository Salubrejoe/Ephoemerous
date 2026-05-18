


import SwiftUI
import CoreLocation

struct CircledResetButton: View {
    @Environment(EAppState.self) var state
    private let loc = ELocationService.shared
    
    var body: some View {
        
        Button {
            state.resetView()
        } label: {
            Image(symbol: .circle)
                .font(.title.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(2)
        .glassEffect(.regular.interactive(), in: .circle)
        .simultaneousGesture(
            LongPressGesture()
                .onEnded { _ in
                    state.projectionMode = .coupled
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation {
                            state.appMode.toggle()
                        }
                        state.projectionMode = .drag
                    }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
        )
    }
}

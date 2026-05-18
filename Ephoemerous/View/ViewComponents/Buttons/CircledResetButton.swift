import SwiftUI

struct CircledResetButton: View {
    @Environment(EAppState.self) var state

    var body: some View {
        Button(action: state.resetView) {
            Image(symbol: .circle)
                .font(.title.weight(.semibold))
                .symbolColorRenderingMode(.gradient)
                .foregroundStyle(.white)
        }
        .padding(2)
        .glassEffect(.clear.interactive(), in: .circle)
        .simultaneousGesture(
            LongPressGesture()
                .onEnded { _ in state.toggleAppMode() }
        )
    }
}

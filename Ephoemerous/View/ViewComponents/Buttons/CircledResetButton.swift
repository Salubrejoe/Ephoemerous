import SwiftUI

struct CircledResetButton: View {
    @Environment(EAppState.self) var state

    var body: some View {
        Button(action: state.resetView) {
            Image(symbol: .circle)
                .font(.footnote.weight(.semibold))
                .symbolColorRenderingMode(.gradient)
                .foregroundStyle(.primary)
        }
        .padding(8)
        .glassEffect(.clear.interactive(), in: .circle)
        .simultaneousGesture(
            LongPressGesture()
                .onEnded { _ in state.toggleAppMode() }
        )
    }
}

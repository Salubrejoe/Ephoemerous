import SwiftUI

struct OmniButton: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(EAppState.self) var state

    var body: some View {
        Button(action: state.toggleAppMode) {
//        Button(action: state.resetView) {
            Image(symbol: .circle)
                .font(.headline.weight(.semibold))
                .symbolColorRenderingMode(.gradient)
                .foregroundStyle(prColor)
        }
        .padding(8)
        .glassEffect(.clear.interactive(), in: Squircle(corners: 7, bulge: 3.5, rotation: .zero))
        .offset(
            x: state.renderedOffset.y,
            y: state.renderedOffset.x
        )
//        .simultaneousGesture(
//            LongPressGesture()
//                .onEnded { _ in state.toggleAppMode() }
//        )
    }
    
    private var prColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

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
                .padding(8)
                .glassEffect(.clear.tint(.baseOrange).interactive(), in: Squircle(corners: 12, bulge: 2.5, rotation: .zero))
//                .background(
//                    Squircle(corners: 7, bulge: 3.5, rotation: .zero)
//                        .fill(.regularMaterial)
//                        .glassEffect()
//                )
        }
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

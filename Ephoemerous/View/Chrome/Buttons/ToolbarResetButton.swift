
import SwiftUI


struct ToolbarResetButton: View {
    let size:   Double
    let symbol: String
    let action: () -> Void
    /// `symbol` names the AXIS the chip resets — the two chips are visually
    /// twins, so identical glyphs would make the user memorise "left = place,
    /// right = time". Give each its own noun.
    init(size: Double,
         symbol: String = "arrow.counterclockwise",
         action: @escaping () -> Void) {
        self.size   = size
        self.symbol = symbol
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.callout.weight(.bold))
                .foregroundStyle(.primary)
                .offset(y: -0.5)
                .frame(width: size, height: size)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Reset chip") {
    PreviewSky.night {
        ToolbarResetButton(size: 32, symbol: "location.fill") {}
    }
}
#endif

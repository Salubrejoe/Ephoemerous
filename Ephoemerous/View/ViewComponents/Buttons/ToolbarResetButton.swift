
import SwiftUI


struct ToolbarResetButton: View {
    let size:   Double
    let action: () -> Void
    init(size: Double, action: @escaping () -> Void) {
        self.size   = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
                .offset(y: -0.5)
                .frame(width: size, height: size)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

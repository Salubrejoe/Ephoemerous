
import SwiftUI


struct ToolbarPill: View {
    let title:  String
    let action: () -> Void
    
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 16)
                .padding(.vertical,    8)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Toolbar pill") {
    PreviewSky.night {
        HStack { ToolbarPill("Here") {}; ToolbarPill("21:30") {} }
    }
}
#endif

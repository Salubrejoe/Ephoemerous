


import SwiftUI
import CoreLocation

struct CircledResetButton: View {
    @Environment(EAppState.self) var state
    private let loc = ELocationService.shared
    
    
    var body: some View {
        
        Button {
            state.apply(.defaultPreset)
        } label: {
            Image(symbol: .circle)
                .font(.title.weight(.semibold))
                .foregroundStyle(disabled ? .gray : .white)
        }
        .padding(2)
        .glassEffect(.regular.interactive(), in: .circle)
        .simultaneousGesture(
            LongPressGesture()
                .onEnded { _ in
                    state.projectionMode = .coupled
                    state.animateOrigin(to: .degrees(90), lon: state.origin.longitude)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        state.appMode.toggle()
                    }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
        )
// TODO: Remove - dead commented-out implementation, superseded by current button body

        
    }
    
    // TODO: Rename - `disabled` shadows SwiftUI's built-in disabled modifier; use `isAtDefaultView` or similar
    var disabled: Bool {
        !(state.scale != 50.0 || state.offset != .init(x: AstroConstants.defaultOffsetX, y: AstroConstants.defaultOffsetY))
    }
}

import SwiftUI
import CoreLocation

struct CircledResetButton: View {
    @Environment(EAppState.self) var state
    private let loc = ELocationService.shared
    var body: some View {
        
        Image(symbol: .circle)
            .font(.title.weight(.semibold))
            .foregroundStyle(disabled ? .gray : .white)
            .onTapGesture {
                switch state.appMode {
                case .clock:
                    state.apply(.defaultPreset)
                case .travel:
                    state.travelDragMode = .coupled
                    state.setOrigin(lat: .degrees(-90), lon: .zero)
                }
            }
            .onLongPressGesture {
                state.appMode.toggle()
                if let l = loc.location {
                    state.animateOrigin(to: .degrees(l.coordinate.latitude), lon: .degrees(l.coordinate.longitude))
                } else { loc.requestIfNeeded() }
            }
        
    }
    
    var disabled: Bool {
        !(state.scale != 50.0 || state.offset != .init(x: AstroConstants.defaultOffsetX, y: AstroConstants.defaultOffsetY))
    }
}
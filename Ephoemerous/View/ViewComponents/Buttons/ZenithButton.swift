import SwiftUI
import CoreLocation


struct ZenithButton: View {
    @Environment(EAppState.self) var state
    private let loc = ELocationService.shared
    @State private var pulsing = false
    
    var body: some View {
        Group {
            if !state.isShowingDatePicker {
                Button {
                    state.haptics.toggle()
                    if let l = loc.location {
                        let currentProjMode = state.projectionMode
                        state.projectionMode = .coupled
                        state.animateOrigin(to: .degrees(l.coordinate.latitude), lon: .degrees(l.coordinate.longitude))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            state.projectionMode = currentProjMode
                        }
                    } else { loc.requestIfNeeded() }
                } label: {
                    Image(symbol: buttonSymbol)
                        .foregroundStyle(iconColor)
                        .scaleEffect(pulsing ? AstroConstants.zenithPulseScale : 1.0)
                        .opacity(pulsing ? 0.5 : 1.0)
                }
                .sensoryFeedback(.selection, trigger: state.haptics)
                .help(helpText)
                .onAppear(perform: loc.requestIfNeeded)
                .onChange(of: isAcquiring, togglePulsingWithAnimation)
            }
        }
    }
}

// MARK: - Helpers
extension ZenithButton {
    private var buttonSymbol: Strings.Symbols {
        isAtUserLocation ? .locationFill : .location
    }
    private var isAtUserLocation: Bool {
        guard let l = loc.location else { return false }
        return abs(state.origin.latitude.degrees  - l.coordinate.latitude)  < 1.0
             && abs(state.origin.longitude.degrees - l.coordinate.longitude) < 1.0
    }
    private var isAcquiring: Bool {
        let auth = loc.authStatus
        return (auth == .authorizedWhenInUse || auth == .authorizedAlways) && loc.location == nil
    }
    private var iconColor: Color {
        switch loc.authStatus {
        case .denied, .restricted:            return .red
        case .authorizedWhenInUse, .authorizedAlways:
            if isAcquiring      { return .yellow }
            if isAtUserLocation { return .baseOrange }
            return .primary.opacity(0.7)
        default: return .secondary
        }
    }
    private var helpText: String {
        state.appMode == .travel ? "Travel mode (long press to exit)" : "Centre on your location"
    }
    
    private func togglePulsingWithAnimation() {
        // TODO: Refactor - `if true` is a placeholder; wire to actual acquiring state
        if isAcquiring {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulsing = true }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { pulsing = false }
        }
    }
}

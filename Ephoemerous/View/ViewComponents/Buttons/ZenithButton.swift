import SwiftUI
import CoreLocation

struct ZenithButton: View {
    @Environment(EAppState.self) var state
    @State private var pulsing = false

    var body: some View {
        Group {
            if !state.isShowingDatePicker {
                Button(action: goToLocation) {
                    Image(symbol: buttonSymbol)
                        .foregroundStyle(iconColor)
                        .scaleEffect(pulsing ? AstroConstants.zenithPulseScale : 1.0)
                        .opacity(pulsing ? 0.5 : 1.0)
                }
                .sensoryFeedback(.selection, trigger: state.haptics)
                .help(helpText)
                .onAppear(perform: ELocationService.shared.requestIfNeeded)
                .onChange(of: state.isAcquiringLocation, updatePulsing)
            }
        }
    }

    private func goToLocation() {
        state.haptics.toggle()
        state.goToDeviceLocation()
    }
}

// MARK: - Presentation
extension ZenithButton {

    private var buttonSymbol: AppSymbol {
        state.isAtDeviceLocation ? .locationFill : .location
    }

    private var iconColor: Color {
        switch ELocationService.shared.authStatus {
        case .denied, .restricted:
            return .red
        case .authorizedWhenInUse, .authorizedAlways:
            if state.isAcquiringLocation { return .yellow }
            if state.isAtDeviceLocation  { return .baseOrange }
            return .primary.opacity(0.7)
        default:
            return .secondary
        }
    }

    private var helpText: String {
        state.appMode == .travel ? "Travel mode (long press to exit)" : "Centre on your location"
    }

    private func updatePulsing() {
        if state.isAcquiringLocation {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                pulsing = false
            }
        }
    }
}

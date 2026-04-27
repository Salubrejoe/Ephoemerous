import SwiftUI
import CoreLocation


struct ZenithButton: View {
    let state: EAppState
    private let loc = ELocationService.shared

    @State private var pulsing = false

    var body: some View {
        Button {
            resetLocationOrRquestPermish()
        } label: {
            Image(symbol: isAtUserLocation ? .locationFill : .location)
                .foregroundStyle(iconColor)
                .scaleEffect(pulsing ? 1.25 : 1.0)
                .opacity(pulsing ? 0.5 : 1.0)
        }
        .help(helpText)
        .onAppear(perform: loc.requestIfNeeded)
        .onChange(of: isAcquiring, togglePulsingWithAnimation)
    }
}


    
// MARK: - Helpers
extension ZenithButton {
    // True when origin is within ~1° of the GPS fix
    private var isAtUserLocation: Bool {
        guard let l = loc.location else { return false }
        let latDiff = abs(state.origin.latitude.degrees  - l.coordinate.latitude)
        let lonDiff = abs(state.origin.longitude.degrees - l.coordinate.longitude)
        return latDiff < 1.0 && lonDiff < 1.0
    }
    
    // Acquiring = authorised but no fix yet
    private var isAcquiring: Bool {
        let auth = loc.authStatus
        let granted = auth == .authorizedWhenInUse || auth == .authorizedAlways
        return granted && loc.location == nil
    }
    
    private var iconColor: Color {
        switch loc.authStatus {
        case .denied, .restricted:
            return .red
        case .authorizedWhenInUse, .authorizedAlways:
            if isAcquiring  { return .yellow }
            if isAtUserLocation { return EArtist.shared.horColor }
            return .primary.opacity(0.7)
        default:
            return .secondary
        }
    }
    
    private var helpText: String {
        switch loc.authStatus {
        case .denied, .restricted:
            return "Location access denied"
        case .authorizedWhenInUse, .authorizedAlways:
            if isAcquiring      { return "Acquiring location..." }
            if isAtUserLocation { return "At your location" }
            return "Centre on your location"
        default:
            return "Tap to enable location"
        }
    }
    
    private func resetLocationOrRquestPermish() {
        if let l = loc.location {
            state.setOrigin(
                lat: .degrees(l.coordinate.latitude),
                lon: .degrees(l.coordinate.longitude)
            )
        } else {
            loc.requestIfNeeded()
        }
    }
    
    private func togglePulsingWithAnimation() {
        if true {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)) {
                    pulsing = true
                }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                pulsing = false
            }
        }
    }
}

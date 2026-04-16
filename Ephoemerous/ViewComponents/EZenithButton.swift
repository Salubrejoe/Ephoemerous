import SwiftUI


struct EZenithButton: View {

    let state: EAppState

    var body: some View {
        Button {
            let z   = state.observerZenith
            let lat = asin(max(-1.0, min(1.0, z.z)))
            let lon = atan2(z.y, z.x)
            state.setOrigin(lat: lat, lon: lon)
        } label: {
            Image(systemName: "location.north.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .padding(.horizontal)
        }
        .help("Centre on zenith")
    }
}

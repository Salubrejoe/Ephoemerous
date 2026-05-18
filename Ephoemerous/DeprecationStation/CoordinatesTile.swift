import SwiftUI

struct CoordinatesTile: View {
    let origin: Origin
    @Environment(EAppState.self) private var state
    
    private var latStr: String {
        let d = origin.latitude.degrees
        return String(format: "%@%.1f°", d >= 0 ? "N " : "S ", abs(d))
    }
    
    private var lonStr: String {
        let d = origin.longitude.degrees
        return String(format: "%@%.1f°", d >= 0 ? "E " : "W ", abs(d))
    }
    
    private var latActive: Bool { state.coupledAxis == .vertical }
    private var lonActive: Bool { state.coupledAxis == .horizontal }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(latStr)
                .font(.caption)
                .fontWeight(latActive ? .semibold : .regular)
                .foregroundStyle(latActive ? Color.orange : .primary)
                .animation(.spring(response: 0.25), value: latActive)
            Text(lonStr)
                .font(.caption)
                .fontWeight(lonActive ? .semibold : .regular)
                .foregroundStyle(lonActive ? Color.orange : .primary)
                .animation(.spring(response: 0.25), value: lonActive)
        }
        .monospaced()
        //        .environment(\.colorScheme, .dark)
//        .padding(.horizontal, 10)
//        .padding(.vertical, 7)
//        .background(
//            RoundedRectangle(cornerRadius: 14, style: .continuous)
//                .fill(.ultraThinMaterial)
//        )
    }
}

#Preview {
    CoordinatesTile(origin: .init(latitude: .degrees(51.5), longitude: .degrees(-0.1)))
        .padding()
}


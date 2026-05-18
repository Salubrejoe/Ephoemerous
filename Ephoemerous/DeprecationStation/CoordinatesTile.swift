import SwiftUI

struct CoordinatesTile: View {
    let origin: Origin
    @Environment(EAppState.self) private var state

    private var latStr: String {
        let d = origin.latitude.degrees
        return String(format: "%@%.2f°", d >= 0 ? "N " : "S ", abs(d))
    }

    private var lonStr: String {
        let d = origin.longitude.degrees
        return String(format: "%@%.2f°", d >= 0 ? "E " : "W ", abs(d))
    }

    private var latActive: Bool { state.coupledAxis == .vertical }
    private var lonActive: Bool { state.coupledAxis == .horizontal }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(latStr)
                .font(.system(size: latActive ? 14 : 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(latActive ? Color.orange : .white)
                .animation(.spring(response: 0.25), value: latActive)
            Text(lonStr)
                .font(.system(size: lonActive ? 14 : 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(lonActive ? Color.orange : .white)
                .animation(.spring(response: 0.25), value: lonActive)
        }
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.5)
        )
    }
}

#Preview {
    CoordinatesTile(origin: .init(latitude: .degrees(51.5), longitude: .degrees(-0.1)))
        .padding()
}

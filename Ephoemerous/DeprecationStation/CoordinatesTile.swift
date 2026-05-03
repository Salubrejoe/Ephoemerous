import SwiftUI
// TODO: Merge or remove - CoordinatesTile and ELocationTile are identical; pick one name and delete the other

struct CoordinatesTile: View {
    let origin: Origin

    private var latStr: String {
        let d = origin.latitude.degrees
        return String(format: "%@%.2f°", d >= 0 ? "N " : "S ", abs(d))
    }

    private var lonStr: String {
        let d = origin.longitude.degrees
        return String(format: "%@%.2f°", d >= 0 ? "E " : "W ", abs(d))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(latStr)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(lonStr)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    CoordinatesTile(origin: .init(latitude: .degrees(51.5), longitude: .degrees(-0.1)))
        .padding()
}

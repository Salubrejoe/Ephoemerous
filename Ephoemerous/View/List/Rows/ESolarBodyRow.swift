
import SwiftUI


struct ESolarBodyRow: View {
    let name      : String
    let subtitle  : String
    let color     : Color
    let magnitude : Double
    let symbol    : String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.semibold))
            }
            Spacer()
            Text(String(format: "%.1f mag", magnitude))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

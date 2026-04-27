
import SwiftUI


struct EStarRowView: View {
    let star: EStar
    var body: some View {
        HStack(spacing: 12) {
            let r = max(AstroConstants.listDotMin, min(AstroConstants.listDotMax, (AstroConstants.listDotScale - star.magnitude) * AstroConstants.listDotFactor))
            Circle().fill(star.spectralClass.color).frame(width: r, height: r)
            VStack(alignment: .leading, spacing: 2) {
                Text(star.displayName).font(.body.weight(.semibold))
                Text(star.constellation.fullName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f mag", star.magnitude)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Text(star.spectralClass.rawValue).font(.caption2).foregroundStyle(star.spectralClass.color)
            }
        }.padding(.vertical, 4)
    }
}


import SwiftUI


struct EStarRowView: View {
    let star: EStar
    var body: some View {
        HStack(spacing: 12) {
            let r = max(AstroConstants.listDotMin, min(AstroConstants.listDotMax, (AstroConstants.listDotScale - star.magnitude) * AstroConstants.listDotFactor))
            Circle().fill(star.spectralClass.color).frame(width: r, height: r)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(star.displayName).font(.body.weight(.semibold))
                Text("@ \(star.constellation.fullName)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f mag", star.magnitude)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
}

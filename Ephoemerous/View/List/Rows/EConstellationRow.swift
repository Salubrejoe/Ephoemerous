
import SwiftUI


struct EConstellationRow: View {
    let constellation: EConstellation
    var body: some View {
        HStack(spacing: 12) {
            Text(constellation.rawValue)
                .font(.system(size: 15, weight: .thin, design: .serif))
                .foregroundStyle(.white)
                .frame(width: 40, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(constellation.fullName).font(.body.weight(.semibold))
                if constellation.isZodiacSign { Text("Zodiac").font(.caption2).foregroundStyle(.yellow.opacity(0.8)) }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

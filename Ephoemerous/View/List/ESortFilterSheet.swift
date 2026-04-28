import SwiftUI

struct ESortFilterSheet: View {
    @Binding var magnitudeCap: Double
    let magnitudeRange: ClosedRange<Double>
    let starCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Strings.Sort.brighterThan)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: Strings.Format.magnFormat, magnitudeCap))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(starCount) stars")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Slider(value: $magnitudeCap, in: magnitudeRange, step: 0.5)
                .tint(.primary)
            
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    ESortFilterSheet(magnitudeCap: .constant(5.5), magnitudeRange: -2...8, starCount: 1234)
}

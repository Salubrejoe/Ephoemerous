import SwiftUI


struct DetailTile: View {
    let icon:  String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 120)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial)
        )
    }
}

#if DEBUG
#Preview("Tile") {
    HStack {
        DetailTile(icon: "ruler", value: "642 ly")
        DetailTile(icon: "sparkles", value: "0.42")
    }
    .padding()
}
#endif

import SwiftUI

struct EStarDetailView: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss
    let star: EStar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                
                    Text(star.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                    HStack {
                        HStack(spacing: 8) {
                            Image(symbol: .rightAscension)
                            Text("\(star.rightAscension.hmsString)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(.regularMaterial)
                        )
                        HStack(spacing: 8) {
                            Image(symbol: .declination)
                            Text("\(star.declination.dmsString)")
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(.regularMaterial)
                        )
                    }
                    .font(.footnote)
                    .monospaced()
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
                
                    EStarInfoGrid(star: star, accent: star.spectralClass.color)
                   
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
//        .navigationTitle(star.displayName)
//        .navigationBarTitleDisplayMode(.inline)
        .background(background())
        .toolbar {
            ToolbarItem(placement: .automatic) {
                SelectStarButton(star: star)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }
    
    var color: Color {
        if state.selectedStars.contains(where: { $0.name == star.name }) {
            star.spectralClass.color
        } else {
            star.spectralClass.color.opacity(0.2)
        }
    }
    
    @ViewBuilder
    private func background() -> some View {
        ZStack {
            Circle()
                .fill(state.selectedStars.contains(where: { $0.name == star.name }) ? star.spectralClass.color : .clear)
                .frame(width: 50, height: 50)
                .blur(radius: 30)
                .padding(25)
        }
        .ignoresSafeArea()
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topTrailing
        )
    }
}

// MARK: - Info grid
private struct EStarInfoGrid: View {
    let star: EStar
    let accent: Color
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            
            EStarTile(
                label: "Magnitude",
                value: String(format: "%.2f", star.magnitude),
                accent: accent,
                symbol: .eyes
            )
            EStarTile(
                label: "Spectral Class",
                value: star.spectralClass.rawValue,
                accent: accent,
                symbol: .hrClass
            )
            EStarTile(
                label: "Distance",
                value: String(format: "%.1f ly", star.distanceLY ?? "Unknown"),
                accent: accent,
                symbol: .distance
            )
            EStarTile(
                label: "Constellation",
                value: star.constellation.fullName,
                accent: accent,
                symbol: .sparkles
            )
        }
    }
}

private struct EStarTile: View {
    let label: String
    let value: String
    let accent: Color
    let symbol: Strings.Symbols
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(symbol: symbol)
                    .imageScale(.small)
                Text(label)
            }
            .font(.footnote)
            .foregroundStyle(accent.opacity(0.8))
            .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(.title3.bold())
                .monospaced()
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.3)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(accent.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}


#Preview {
    NavigationStack {
        EStarDetailView(star: EStar.mockStars[0])
    }
    .environment(EAppState())
    .preferredColorScheme(.dark)
}

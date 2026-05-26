
import SwiftUI
import LoreKit


struct SelectStarButton: View {
    @Environment(EAppState.self) var state
    let star: EStar
    var body: some View {
        Button {
            if starIsSelected {
                state.selectedStars.removeAll { $0.name == star.name }
            } else {
                state.selectedStars.append(star)
                state.applyStarTracking(star)
            }
        } label: {
            ZStack {
                Image(symbol: state.selectedStars.contains(where: { $0.name == star.name }) ? .target : .circle)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 33, height: 33)
                    .shadow(
                        color: state.selectedStars.contains(where: { $0.name == star.name }) ? star.spectralClass.color : .clear,
                        radius: 5
                    )
            }
        }
        .foregroundStyle(color)
    }
    
    private var color: Color {
        if state.selectedStars.contains(where: { $0.name == star.name }) {
            star.spectralClass.color
        } else {
            star.spectralClass.color.opacity(0.3)
        }
    }
    
    private var starIsSelected: Bool {
        state.selectedStars.contains(where: { $0.name == star.name })
    }
}

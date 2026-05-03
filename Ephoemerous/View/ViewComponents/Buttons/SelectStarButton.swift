
import SwiftUI


struct SelectStarButton: View {
    @Environment(EAppState.self) var state
    let star: EStar
    var body: some View {
        Button {
            if state.selectedStars.contains(where: { $0.name == star.name }) {
                state.selectedStars.removeAll { $0.name == star.name }
            } else {
                // TODO: Remove inner contains check - outer if/else already guarantees star is not selected
                if !state.selectedStars.contains(where: { $0.name == star.name }) {
                    state.selectedStars.append(star)
                    state.applyStarTracking(star)
                }
            }
        } label: {
            ZStack {
                Image(symbol: state.selectedStars.contains(where: { $0.name == star.name }) ? .target : .circle)
                    .shadow(
                        color: state.selectedStars.contains(where: { $0.name == star.name }) ? star.spectralClass.color : .clear,
                        radius: 5
                    )
            }
        }
        .foregroundStyle(color)
    }
    
    var color: Color {
        if state.selectedStars.contains(where: { $0.name == star.name }) {
            star.spectralClass.color
        } else {
            star.spectralClass.color.opacity(0.3)
        }
    }
}

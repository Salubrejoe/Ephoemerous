import SwiftUI

struct SkyTestView: View {

    @State private var phaseIndex = 0
    @State private var blendFactor: Double = 0

    private var currentPhase: ESkyPhase {
        ESkyPhase.allCases[phaseIndex]
    }

    private var nextPhase: ESkyPhase {
        ESkyPhase.allCases[(phaseIndex + 1) % ESkyPhase.allCases.count]
    }

    var body: some View {
        ZStack {
            currentPhase.gradient
            nextPhase.gradient
                .opacity(blendFactor)

            VStack {
                Spacer()

                Text(label(for: currentPhase))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .shadow(radius: 4)

                Text("→ \(label(for: nextPhase))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .shadow(radius: 2)

                Spacer().frame(height: 60)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 1.2)) {
                blendFactor = 1.0
            } completion: {
                phaseIndex = (phaseIndex + 1) % ESkyPhase.allCases.count
                blendFactor = 0
            }
        }
    }

    private func label(for phase: ESkyPhase) -> String {
        switch phase {
        case .night:     "Night"
        case .civilDawn: "Civil Dawn"
        case .sunrise:   "Sunrise"
        case .morning:   "Morning"
        case .midday:    "Midday"
        case .afternoon: "Afternoon"
        case .sunset:    "Sunset"
        case .civilDusk: "Civil Dusk"
        }
    }
}

#Preview {
    SkyTestView()
}

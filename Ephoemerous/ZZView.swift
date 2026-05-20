
import SwiftUI


struct ZZView: View {
    @Environment(EAppState.self) var state
    @State private var isPresented : Bool = true
    var body: some View {
        NavigationStack {
            ZStack {
                RadialGradient(colors: [
                    .blue,
                    .pink
                ], center: .center, startRadius: .zero, endRadius: 400)
                .ignoresSafeArea()
                DoubleButton()
                    .padding(.bottom, 66)
                    .padding(.trailing, 24)
            }
            
            .sheet(isPresented: $isPresented) {
                HStack {
                    Capsule()
                    Circle()
                    Circle()
                }
                    .padding(14)
                    .interactiveDismissDisabled()
                    .scrollContentBackground(.hidden)
                    .presentationDragIndicator(.visible)
                    .presentationDetents(
                        [
                            .height(66),
                            .medium,
                            //                            .large
                        ]
                    )
                    .presentationBackgroundInteraction(.enabled)
            }
        }
    }
    
    @ViewBuilder
    private func DoubleButton() -> some View {
        
        VStack(spacing: 0) {
            Image(symbol: .magnitudeIcon)
                .frame(width: 22, height: 22)
                .padding(.horizontal, 14)
            
            Divider()
                .padding(.vertical, 12)
            Image(symbol: .circle)
                .frame(width: 22, height: 22)
                .padding(.horizontal, 14)
        }
        .frame(width: 48, height: 100)
        .glassEffect(.regular.interactive(), in: .buttonBorder)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}


#Preview {
    ZZView().environment(EAppState())
}


import SwiftUI

struct ConstellationCard: View {
    let constellation: Constellation

    var body: some View {
        
        
        HStack {
            Artist.shared.constellationFigure(constellation)
            Text(constellation.localizedName)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.1)
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .glassEffect(.regular.interactive())
    }
}

#if DEBUG
#Preview {
    StarCard(star: .mockStars.last!)
    ConstellationCard(constellation: .And)
}
#endif

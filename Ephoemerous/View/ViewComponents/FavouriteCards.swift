import SwiftUI


struct StarCard: View {
    let star: Star

    var body: some View {
        HStack {
            POILabelView(category: .followedStar(star), text: "", labelStyle: .star)
            Text(star.displayName)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.4)
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .glassEffect(.regular.interactive())
        .padding(.vertical, 8)
    }
}


struct ConstellationCard: View {
    let constellation: Constellation

    var body: some View {
        
        
        HStack {
            Image(systemName: "sparkles")
            Text(constellation.localizedName)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.1)
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .glassEffect(.regular.interactive())
    }
}


#Preview {
    StarCard(star: .mockStars.last!)
    ConstellationCard(constellation: .And)
}

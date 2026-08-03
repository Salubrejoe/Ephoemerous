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


import SwiftUI


struct SearchBar: View {
    @Binding var showStarList: Bool
    
    var body: some View {
        Button {
            showStarList.toggle()
        } label: {
            HStack {
                Image(symbol: .search)
                Text(Strings.Prompts.searchBar)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .animation(.bouncy, value: showStarList)
    }
}

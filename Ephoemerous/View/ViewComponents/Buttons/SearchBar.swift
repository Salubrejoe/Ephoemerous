
import SwiftUI
// TODO: Audit - SearchBar takes @Binding<Bool> but EAppState already owns showStarList; consider @Environment instead


struct SearchBar: View {
    @Environment(EAppState.self) var state
    
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
        .padding(.horizontal)
        .animation(.bouncy, value: showStarList)
    }
}

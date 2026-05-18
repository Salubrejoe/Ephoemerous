
import SwiftUI

struct SearchBar: View {
    @Environment(EAppState.self) var state
    
    var body: some View {
        VStack {
            
            if !state.showStarList {
                Button {
                    state.showStarList.toggle()
                } label: {
                    HStack {
                        Image(symbol: .search)
                        Text(Strings.Prompts.searchBar)
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.gray)
                }
                .padding(.horizontal)
                .padding(.vertical)
                .glassEffect()
                .animation(.bouncy, value: state.showStarList)
            }
        }
    }
}

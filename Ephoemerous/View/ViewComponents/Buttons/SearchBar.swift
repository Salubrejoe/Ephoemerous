
import SwiftUI

struct SearchBar: View {
    @Environment(EAppState.self) var state
    
    var body: some View {
        Group {
            if !state.isShowingDatePicker || state.showStarList {
                Button {
                    state.showStarList.toggle()
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
                .animation(.bouncy, value: state.showStarList)
            }
        }
    }
}

// DEPRECATED — toggled `state.showStarList` which is gone with
// EListView. The bottom-toolbar search icon now opens the new
// `SearchSheet` directly. Wrapped in `#if false`.

#if false
import SwiftUI
import LoreKit

struct SearchBar: View {
    @Environment(EAppState.self) var state

    var body: some View {
        VStack {

//            if !state.showStarList {
                Button {
                    state.showStarList.toggle()
                } label: {
                    HStack {
                        Image(symbol: .search)
                        Text(Strings.Prompts.searchBar)
                        Spacer()
                    }
                    .font(.footnote)
                    .foregroundStyle(.gray)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 18)
                .glassEffect(.clear.interactive(), in: .capsule)
                .animation(.bouncy, value: state.showStarList)
//            }
        }
    }
}
#endif

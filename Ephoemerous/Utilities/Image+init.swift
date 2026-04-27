
import SwiftUI


extension Image {
    init(symbol: Strings.Symbols) {
        self.init(systemName: symbol.description)
    }
}

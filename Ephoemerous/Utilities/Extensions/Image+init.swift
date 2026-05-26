
import SwiftUI


// Project-local specialised init so leading-dot shorthand works at call
// sites — `Image(symbol: .checkmark)` instead of `Image(symbol: Strings.Symbols.checkmark)`.
// Swift can't resolve `.checkmark` against LoreKit's *generic*
// `RawRepresentable` init (the compiler needs a concrete type), so each
// app keeps a one-liner that pins the type. The systemName lookup itself
// is the same as LoreKit's generic, just specialised here.
extension Image {
    init(symbol: Strings.Symbols) {
        self.init(systemName: symbol.description)
    }
}

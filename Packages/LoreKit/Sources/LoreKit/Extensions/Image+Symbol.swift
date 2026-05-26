import SwiftUI

// MARK: - Image(symbol:)
// Compile-checked SF Symbol initializer. Lets a project define its own
// String-backed symbol enum and feed it straight to `Image` without the
// stringly-typed footgun of `Image(systemName:)`, where a typo silently
// renders a placeholder at runtime.
//
//   enum AppSymbol: String {
//       case checkmark = "checkmark"
//       case calendar  = "calendar"
//   }
//
//   Image(symbol: AppSymbol.checkmark)
//   // ↓ resolves to
//   Image(systemName: "checkmark")
//
// Any `RawRepresentable` whose `RawValue == String` works — enums are
// the obvious fit, but a custom type that vends an SF Symbol name does
// too. LoreKit owns the generic plumbing; each project brings its own
// symbol vocabulary.
//
// Caveat: Swift can't resolve a *leading-dot* shorthand against a
// generic constraint — `Image(symbol: .checkmark)` won't compile here
// because the compiler can't pick which `RawRepresentable<String>` you
// mean. If you want that ergonomics, add a one-line project-local init
// that pins the type:
//
//   extension Image {
//       init(symbol: AppSymbol) { self.init(systemName: symbol.rawValue) }
//   }
//
// LoreKit's generic still serves the fully-qualified form
// (`Image(symbol: AppSymbol.checkmark)`) for free.
public extension Image {
    init<S: RawRepresentable>(symbol: S) where S.RawValue == String {
        self.init(systemName: symbol.rawValue)
    }
}

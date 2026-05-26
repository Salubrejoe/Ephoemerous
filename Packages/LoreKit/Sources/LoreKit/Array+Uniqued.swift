import Foundation

// MARK: - Array.uniqued(by:)
// Stable-order dedup keyed by a `Hashable` projection.
// `users.uniqued(by: \.id)` keeps the first instance of each id.
public extension Array {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}

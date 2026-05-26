import Foundation

// MARK: - Date.timeString
// Short locale-aware time string for the receiver — "9:32 AM" /
// "21:32" depending on locale. Skips the date component entirely.
public extension Date {
    var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: self)
    }
}

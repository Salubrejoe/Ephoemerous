import Foundation

extension Date {
    var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: self)
    }
}
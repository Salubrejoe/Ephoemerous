import Foundation

struct TimeFormatter {

    static func format(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes      = totalSeconds / 60
        let seconds      = totalSeconds % 60

        if minutes > 0 {
            return "\(minutes)m\(seconds)s"
        } else {
            return "\(seconds)"
        }
    }
}

#if DEBUG
import Foundation

// MARK: - MemoryLog
// Launched with `-memlog`, the app writes its memory footprint to
// Documents/memlog.txt once a second — the number jetsam judges it by.
// Written line by line, so it survives a jetsam kill, and readable off a
// device with `devicectl device copy from --domain-type appDataContainer`.
// (The render server's share — `backboardd` — isn't visible from here.)
enum MemoryLog {

    private static var file:  FileHandle?
    private static let start = Date.now

    static func startIfAsked() {
        guard ProcessInfo.processInfo.arguments.contains("-memlog") else { return }
        let url = URL.documentsDirectory.appending(path: "memlog.txt")
        try? Data().write(to: url)
        file = try? FileHandle(forWritingTo: url)
        Task {
            while true {
                note(String(format: "%8.1f MB", footprintMB()))
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// One timestamped line in the log — a no-op unless it's running.
    static func note(_ text: String) {
        guard let file else { return }
        let line = String(format: "%7.1f s  ", Date.now.timeIntervalSince(start)) + text + "\n"
        file.seekToEndOfFile()
        file.write(Data(line.utf8))
    }

    /// Physical footprint, in MB.
    static func footprintMB() -> Double {
        var info  = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size
                                           / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }
}
#endif

import Foundation
import Observation

@Observable
final class MenuBarViewModel {
    private let monitor: SessionMonitor

    init(monitor: SessionMonitor) {
        self.monitor = monitor
    }

    var activeSessions: [ClaudeSession] {
        monitor.sessions.filter { $0.status != .stale }
    }

    var staleSessions: [ClaudeSession] {
        monitor.sessions.filter { $0.status == .stale }
    }

    var hasAnyBusySession: Bool {
        monitor.sessions.contains { $0.status == .busy }
    }

    var statusSummary: String {
        let total = monitor.sessions.count
        let busy = monitor.sessions.filter { $0.status == .busy }.count

        if total == 0 {
            return "No active sessions"
        }
        if busy > 0 {
            return "\(busy) busy, \(total) total"
        }
        return "\(total) session\(total == 1 ? "" : "s")"
    }

    var overallStatus: SessionStatus {
        monitor.overallStatus
    }
}

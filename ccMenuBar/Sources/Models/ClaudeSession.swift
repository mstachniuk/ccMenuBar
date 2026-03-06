import Foundation

struct ClaudeSession: Identifiable, Equatable {
    let id: String
    var status: SessionStatus
    var cwd: String
    var projectName: String
    var gitBranch: String?
    var lastEvent: String?
    var toolName: String?
    var timestamp: Date
    var source: SessionSource

    enum SessionSource: Equatable {
        case plugin    // From cc-menubar-plugin status files
        case fallback  // From JSONL mtime polling
    }

    var relativeTime: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 5 {
            return "just now"
        } else if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
}

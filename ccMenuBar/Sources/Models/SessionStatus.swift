import Foundation

enum SessionStatus: String, Codable, Comparable {
    case busy
    case idle
    case active
    case stale

    var displayName: String {
        switch self {
        case .busy: return "Busy"
        case .idle: return "Idle"
        case .active: return "Active"
        case .stale: return "Stale"
        }
    }

    /// Sort priority: busy first, then active, idle, stale last
    private var sortOrder: Int {
        switch self {
        case .busy: return 0
        case .active: return 1
        case .idle: return 2
        case .stale: return 3
        }
    }

    static func < (lhs: SessionStatus, rhs: SessionStatus) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

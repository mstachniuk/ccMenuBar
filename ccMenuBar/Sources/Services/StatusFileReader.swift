import Foundation

/// Reads and parses plugin status JSON files from ~/.claude/ccMenuBar/sessions/
enum StatusFileReader {
    struct StatusFile: Decodable {
        let session_id: String
        let status: String
        let cwd: String
        let last_event: String
        let tool_name: String
        let parent_session_id: String?
        let timestamp: String
    }

    static func read(at url: URL) -> ClaudeSession? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let status = try? JSONDecoder().decode(StatusFile.self, from: data) else { return nil }

        let sessionStatus: SessionStatus
        switch status.status {
        case "busy": sessionStatus = .busy
        case "idle": sessionStatus = .idle
        case "active": sessionStatus = .active
        default: sessionStatus = .active
        }

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.date(from: status.timestamp) ?? Date()

        let projectName = ProjectNameResolver.resolve(fromPath: status.cwd)
        let gitBranch = ProjectNameResolver.gitBranch(at: status.cwd)

        let parentId = status.parent_session_id.flatMap { $0.isEmpty ? nil : $0 }

        return ClaudeSession(
            id: status.session_id,
            status: sessionStatus,
            cwd: status.cwd,
            projectName: projectName,
            gitBranch: gitBranch,
            lastEvent: status.last_event,
            toolName: status.tool_name.isEmpty ? nil : status.tool_name,
            timestamp: timestamp,
            source: .plugin,
            parentId: parentId
        )
    }

    /// Read all session files from the status directory
    static func readAll(from directory: URL) -> [ClaudeSession] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { read(at: $0) }
    }
}

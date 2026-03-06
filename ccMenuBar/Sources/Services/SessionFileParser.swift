import Foundation

/// Fallback: discovers sessions by scanning ~/.claude/projects/*/  JSONL files
/// Uses file modification time to infer busy/idle status
enum SessionFileParser {
    private static let claudeProjectsDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }()

    /// Discovers sessions from JSONL file mtimes (fallback when plugin is not installed)
    static func discoverFallbackSessions() -> [ClaudeSession] {
        let fm = FileManager.default
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: claudeProjectsDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return [] }

        var sessions: [ClaudeSession] = []

        for projectDir in projectDirs {
            guard let jsonlFiles = try? fm.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { continue }

            let activeJsonl = jsonlFiles.filter { $0.pathExtension == "jsonl" }

            for file in activeJsonl {
                guard let attrs = try? fm.attributesOfItem(atPath: file.path),
                      let mtime = attrs[.modificationDate] as? Date else { continue }

                let age = Date().timeIntervalSince(mtime)

                // Skip files not modified in the last hour
                guard age < 3600 else { continue }

                let sessionId = file.deletingPathExtension().lastPathComponent
                let projectEncodedName = projectDir.lastPathComponent
                let projectName = ProjectNameResolver.resolve(from: projectEncodedName)

                // mtime < 5s = busy, otherwise idle
                let status: SessionStatus = age < 5 ? .busy : .idle

                let cwd = decodeCwd(from: projectEncodedName)

                sessions.append(ClaudeSession(
                    id: sessionId,
                    status: status,
                    cwd: cwd,
                    projectName: projectName,
                    gitBranch: ProjectNameResolver.gitBranch(at: cwd),
                    lastEvent: nil,
                    toolName: nil,
                    timestamp: mtime,
                    source: .fallback
                ))
            }
        }

        return sessions
    }

    /// Best-effort decode of the encoded project directory name back to a path
    private static func decodeCwd(from encoded: String) -> String {
        // Claude encodes `/Users/foo/bar` as `-Users-foo-bar`
        let path = "/" + encoded.dropFirst().replacingOccurrences(of: "-", with: "/")
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
        // If the simple decode doesn't match a real path, return the encoded form
        return encoded
    }
}

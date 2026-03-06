import Foundation

enum ProjectNameResolver {
    /// Decodes Claude Code encoded project directory names.
    /// Claude encodes paths like `/Users/marcin/code/myproject` as `-Users-marcin-code-myproject`
    static func resolve(from encodedName: String) -> String {
        // The encoded name uses dashes for path separators
        // Extract the last meaningful component as the project name
        let components = encodedName.split(separator: "-").map(String.init)
        return components.last ?? encodedName
    }

    /// Extracts project name from a working directory path
    static func resolve(fromPath path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    /// Attempts to read the current git branch from a working directory
    static func gitBranch(at path: String) -> String? {
        let headFile = URL(fileURLWithPath: path).appendingPathComponent(".git/HEAD")
        guard let content = try? String(contentsOf: headFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        let prefix = "ref: refs/heads/"
        if content.hasPrefix(prefix) {
            return String(content.dropFirst(prefix.count))
        }
        // Detached HEAD - return short hash
        if content.count >= 7 {
            return String(content.prefix(7))
        }
        return nil
    }
}

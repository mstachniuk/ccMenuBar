import Foundation
import Observation

@Observable
final class SessionMonitor {
    var sessions: [ClaudeSession] = []

    var overallStatus: SessionStatus {
        if sessions.contains(where: { $0.status == .busy }) {
            return .busy
        }
        if sessions.contains(where: { $0.status == .active }) {
            return .active
        }
        if sessions.contains(where: { $0.status == .idle }) {
            return .idle
        }
        return .idle
    }

    private let statusDirectory: URL
    private var fsEventStream: FSEventStreamRef?
    private var pollTimer: Timer?
    private let staleThreshold: TimeInterval = 3600 // 1 hour

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        statusDirectory = home.appendingPathComponent(".claude/ccMenuBar/sessions")

        // Ensure status directory exists
        try? FileManager.default.createDirectory(at: statusDirectory, withIntermediateDirectories: true)
    }

    func start() {
        startFSEvents()
        startPollTimer()
        refresh()
    }

    func stop() {
        stopFSEvents()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refresh() {
        var allSessions: [String: ClaudeSession] = [:]

        // Primary: read plugin status files
        let pluginSessions = StatusFileReader.readAll(from: statusDirectory)
        for session in pluginSessions {
            allSessions[session.id] = session
        }

        // Fallback: discover from JSONL mtimes (only add sessions not already found via plugin)
        let fallbackSessions = SessionFileParser.discoverFallbackSessions()
        for session in fallbackSessions {
            if allSessions[session.id] == nil {
                allSessions[session.id] = session
            }
        }

        // Mark stale sessions
        var result = Array(allSessions.values)
        for i in result.indices {
            let age = Date().timeIntervalSince(result[i].timestamp)
            if age > staleThreshold {
                result[i].status = .stale
            }
        }

        // Sort: busy first, then by timestamp (most recent first)
        result.sort { a, b in
            if a.status != b.status {
                return a.status < b.status
            }
            return a.timestamp > b.timestamp
        }

        sessions = result
    }

    // MARK: - FSEvents

    private func startFSEvents() {
        let path = statusDirectory.path as CFString
        let pathsToWatch = [path] as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagUseCFTypes) |
            UInt32(kFSEventStreamCreateFlagFileEvents) |
            UInt32(kFSEventStreamCreateFlagNoDefer)

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1, // 100ms latency
            flags
        ) else { return }

        fsEventStream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    private func stopFSEvents() {
        guard let stream = fsEventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        fsEventStream = nil
    }

    // MARK: - Poll Timer (fallback)

    private func startPollTimer() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
}

// FSEvents C callback
private func fsEventCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let monitor = Unmanaged<SessionMonitor>.fromOpaque(info).takeUnretainedValue()
    DispatchQueue.main.async {
        monitor.refresh()
    }
}

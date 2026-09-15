# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

All Swift commands must be run from the `ccMenuBar/` subdirectory (where `Package.swift` lives):

```sh
cd ccMenuBar
swift build              # Debug build
swift build -c release   # Release build
swift run                # Build and run
```

No Xcode project — everything builds with Swift Package Manager. No external dependencies.

**Requires**: macOS 14+ (Sonoma), Swift 5.9+

### Testing Hook Scripts

```sh
# Write a test session
echo '{"session_id":"test-1","cwd":"/tmp/proj","hook_event_name":"PreToolUse","tool_name":"Bash"}' \
  | ~/.claude/ccMenuBar/scripts/update-status.sh

# Remove it
echo '{"session_id":"test-1"}' | ~/.claude/ccMenuBar/scripts/remove-session.sh
```

## Architecture

Two components communicate via JSON files in `~/.claude/ccMenuBar/sessions/`:

### Claude Code Plugin (`cc-menubar-plugin/`)

Shell scripts installed to `~/.claude/ccMenuBar/scripts/` and registered as hooks in `~/.claude/settings.json`. On each Claude Code event, `update-status.sh` writes a `<session_id>.json` status file; `remove-session.sh` deletes it on `SessionEnd`. Scripts use `sed` for JSON parsing (no `jq` dependency). Writes are atomic (tmp file + `mv`). Source scripts live in `cc-menubar-plugin/scripts/`.

### macOS Menu Bar App (`ccMenuBar/Sources/`)

```
Plugin JSON files ──→ SessionMonitor (@Observable)
JSONL mtime poll  ──→     │
                          ↓
                    MenuBarViewModel (@Observable)
                          ↓
                    AppDelegate (NSStatusItem + NSPopover)
                          ↓
                    SessionListView / SessionRowView (SwiftUI)
```

**Dual monitoring strategy in `SessionMonitor`:**
- **Primary**: FSEvents watches `~/.claude/ccMenuBar/sessions/` (300ms latency, file-level events)
- **Fallback**: 3s Timer polls `~/.claude/projects/*/` JSONL mtimes for sessions without the plugin (mtime < 5s = busy)
- Sessions older than 1 hour are marked stale

**AppKit/SwiftUI hybrid**: `AppDelegate` owns the `NSStatusItem` and `NSPopover`. The popover hosts SwiftUI views via `NSHostingController`. The dock icon is hidden with `NSApp.setActivationPolicy(.accessory)`.

**Icon animation**: A 0.5s timer in `AppDelegate` toggles between `terminal` and `terminal.fill` SF Symbols with orange tint when any session is busy.

## Key Patterns

- `@Observable` (Observation framework) on `SessionMonitor` and `MenuBarViewModel` — no Combine
- FSEvents via CoreFoundation C API (`FSEventStreamRef`) with `Unmanaged` pointer bridging for the callback
- Status enum (`SessionStatus`) has `Comparable` conformance for sort-by-priority (busy → active → idle → stale)
- `ClaudeSession.source` distinguishes `.plugin` vs `.fallback` origin to avoid deduplication conflicts
- Views use `@ViewState` (`Sources/Views/ViewState.swift`), **not** `@State` — `@State` is a macro in the macOS 26+ SDKs and its `SwiftUIMacros` plugin ships only with Xcode.app, so `@State` breaks `swift build` under the Command Line Tools

## Plugin Hook Events

The plugin maps Claude Code hook events to session statuses in `update-status.sh`:
- `PreToolUse`, `PostToolUse` → `busy`
- `SessionStart` → `active`
- `Stop`, `Notification` (idle_prompt) → `idle`
- `SessionEnd` → triggers `remove-session.sh` (deletes session file)

Hook registrations are defined in `cc-menubar-plugin/hooks/hooks.json`. Plugin metadata lives in `cc-menubar-plugin/.claude-plugin/plugin.json`.

## Plugin Installation (via Marketplace)

```sh
claude plugin marketplace add mstachniuk/ccMenuBar   # Register in marketplace
claude plugin install cc-menubar-plugin               # Install locally
claude plugin list                                    # Verify
claude plugin remove cc-menubar-plugin                # Uninstall
```
